#!/usr/bin/env node
/**
 * 1.1.71 基线上从镜像存档的未合并 PR 里挑出的修复回归
 * （上游 YuJunZhiXue/dsh-purge PR #110 / Refs #108，mmparko 存档 519280b）。
 *
 * 本 fork 的 1.1.71 与上游 1.1.71 的 lib/redteam/index.js 逐字节相同、
 * lib/uninstall.js 结构也一致，因此 PR #110 的两半都能移植：
 *   A. 卸载：stripPluginFromPackage / pkgMentionsPurge 同时处理
 *      pkg.dsh.profile.bundles/plugins（现行形状）与四个依赖键，避免悬空 bundle id
 *      和「只写在 optional/peer 里」的半卸载。
 *   B. 停用：releaseOwnDefault() 把仍指向 redteam 的 selectedDefault 交还给
 *      config.default，避免 agent-preset/not-found 让所有工作区建不出新会话。
 *
 * 只用内存夹具与临时目录，不碰真实安装目录。
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import assert from "node:assert/strict";

import { listInstalledProfiles, stripPluginFromPackage } from "../lib/uninstall.js";
import { releaseOwnDefault } from "../lib/redteam/index.js";

let pass = 0;
let fail = 0;
const failures = [];

function check(name, fn) {
  return Promise.resolve()
    .then(fn)
    .then(() => { pass += 1; console.log(`PASS  ${name}`); })
    .catch((e) => {
      fail += 1;
      failures.push(`${name}: ${e && e.message ? e.message : e}`);
      console.log(`FAIL  ${name}  ${e && e.message ? e.message : e}`);
    });
}

function fixture(setup) {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "dsh-purge-1171-pr110-"));
  const profiles = path.join(home, "profiles");
  fs.mkdirSync(profiles, { recursive: true });
  setup(profiles);
  return home;
}

function writeProfile(profiles, name, pkg) {
  const dir = path.join(profiles, name);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "package.json"), JSON.stringify(pkg, null, 2));
  return dir;
}

const DEP_KEYS = ["dependencies", "devDependencies", "optionalDependencies", "peerDependencies"];

async function main() {
  // ── A. 卸载名单与 strip 的四个依赖键 ───────────────────────────────
  for (const key of DEP_KEYS) {
    await check(`A1 ${key} 里的安装会被列进清理名单`, () => {
      const home = fixture((p) => writeProfile(p, "only", { [key]: { "dsh-purge": "^1.1.71" } }));
      assert.ok(listInstalledProfiles(home).some((x) => x.name === "only"), `${key} 漏列`);
    });
  }

  await check("A2 spec 从四个键里都能取到", () => {
    const specs = {};
    const home = fixture((p) => {
      for (const key of DEP_KEYS) {
        writeProfile(p, key, { [key]: { "dsh-purge": `${key}-spec` } });
        specs[key] = `${key}-spec`;
      }
    });
    const got = Object.fromEntries(listInstalledProfiles(home).map((x) => [x.name, x.spec]));
    assert.deepEqual(got, specs);
  });

  await check("A3 strip 四个依赖键且幂等、不误删别的依赖", () => {
    for (const key of DEP_KEYS) {
      const pkg = { [key]: { "dsh-purge": "^1.1.71", other: "1.0.0" } };
      assert.equal(stripPluginFromPackage(pkg), true, `${key} 应命中`);
      assert.equal(Object.hasOwn(pkg[key], "dsh-purge"), false, `${key} 未删`);
      assert.equal(pkg[key].other, "1.0.0", `${key} 误删别的依赖`);
      assert.equal(stripPluginFromPackage(pkg), false, `${key} 不幂等`);
    }
  });

  await check("A4 pkg.dsh.profile.bundles/plugins 的提及判定命中", () => {
    const home = fixture((p) => writeProfile(p, "nested", { dsh: { profile: { bundles: ["dsh-purge@1.1.71"], plugins: [{ id: "dsh-purge" }] } } }));
    assert.equal(listInstalledProfiles(home)[0].name, "nested");
  });

  await check("A5 strip 同时清顶层与 dsh.profile 下的 bundles/plugins", () => {
    const pkg = {
      bundles: ["dsh-purge@1.1.71", "keep-me"],
      plugins: [{ id: "dsh-purge" }, { name: "other" }],
      dsh: { profile: { bundles: ["dsh-purge"], plugins: [{ name: "dsh-purge" }, { id: "keep" }] } },
    };
    assert.equal(stripPluginFromPackage(pkg), true);
    assert.deepEqual(pkg.bundles, ["keep-me"]);
    assert.deepEqual(pkg.plugins, [{ name: "other" }]);
    assert.deepEqual(pkg.dsh.profile.bundles, []);
    assert.deepEqual(pkg.dsh.profile.plugins, [{ id: "keep" }]);
    assert.equal(stripPluginFromPackage(pkg), false, "二次 strip 应无变化");
  });

  await check("A6 无关 profile 不被误列；空值 / 无 package.json 不炸", () => {
    const home = fixture((p) => {
      writeProfile(p, "clean", { dependencies: { other: "1.0.0" } });
      writeProfile(p, "empty", {});
      fs.mkdirSync(path.join(p, "nopkg"), { recursive: true });
    });
    assert.deepEqual(listInstalledProfiles(home), []);
  });

  // ── B. releaseOwnDefault ───────────────────────────────────────────
  const registryOf = (selected, fallback) => ({
    config: {
      selectedDefault: { get: () => selected },
      default: { get: () => fallback },
    },
  });

  await check("B1 默认不是 redteam 时不动宿主配置", async () => {
    let calls = 0;
    const r = await releaseOwnDefault({ registry: registryOf("standard", "standard"), settings: { update: () => { calls += 1; } } });
    assert.equal(r.action, "skipped");
    assert.equal(calls, 0);
  });

  await check("B2 默认是 redteam 时交还 config.default", async () => {
    const calls = [];
    const statuses = [];
    const r = await releaseOwnDefault({
      registry: registryOf("redteam", "standard"),
      settings: { update: (ns, patch) => { calls.push([ns, patch]); } },
      onStatus: (s) => statuses.push(s),
    });
    assert.equal(r.action, "released");
    assert.deepEqual(calls, [["agent-preset-registry", { selectedDefault: "standard" }]]);
    assert.equal(statuses.at(-1).phase, "released-default");
  });

  await check("B3 settings 不可用 / fallback 为空或自指时只落状态、不写", async () => {
    for (const [fallback, settings] of [
      ["standard", null],
      ["", { update: () => { throw new Error("不应被调用"); } }],
      ["redteam", { update: () => { throw new Error("不应被调用"); } }],
    ]) {
      const r = await releaseOwnDefault({
        registry: registryOf("redteam", fallback),
        settings,
        onStatus: (s) => assert.equal(s.phase, "release-default-skipped"),
      });
      assert.equal(r.action, "skipped", `fallback=${fallback}`);
    }
  });

  await check("B4 settings.update 失败被吞掉、记状态、不阻塞停用", async () => {
    const statuses = [];
    const r = await releaseOwnDefault({
      registry: registryOf("redteam", "standard"),
      settings: { update: () => { throw new Error("boom"); } },
      onStatus: (s) => statuses.push(s),
    });
    assert.equal(r.action, "failed");
    assert.equal(statuses.at(-1).phase, "release-default-failed");
  });

  await check("B5 registry 缺失 / getter 抛错时不抛异常", async () => {
    for (const registry of [null, {}, { config: { selectedDefault: { get: () => { throw new Error("no config"); } } } }]) {
      const r = await releaseOwnDefault({ registry, settings: { update: () => {} } });
      assert.ok(["skipped", "failed"].includes(r.action));
    }
  });

  await check("B6 dispose 里确实调用了 releaseOwnDefault（静态契约）", () => {
    const src = fs.readFileSync(new URL("../lib/redteam/index.js", import.meta.url), "utf8");
    assert.match(src, /void releaseOwnDefault\(\{/, "dispose 没有接上交还逻辑");
    assert.ok(src.indexOf("void undeclare()") < src.indexOf("void releaseOwnDefault({"), "交还应排在 undeclare 之后");
  });

  console.log("────────────────────────────────────────");
  console.log(`PASS ${pass}  FAIL ${fail}`);
  if (fail) {
    console.error(failures.join("\n"));
    process.exitCode = 1;
  }
}

main();
