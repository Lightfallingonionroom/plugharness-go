#!/usr/bin/env node
/**
 * 从 mmparko 镜像存档的未合并 PR 里挑出的两条仍有效修复的回归
 * （上游 YuJunZhiXue/dsh-purge PR #110 / Refs #108，原 mm 提交 519280b）。
 *
 * 背景：本 fork 在 1.1.81 已回灌 PR #110 的「卸载清 dsh.profile.bundles/plugins」
 * 那一半，但漏了另外两处：
 *   A. lib/uninstall.js 的 pkgMentionsPurge() 只认 dependencies/devDependencies，
 *      而同文件 stripPluginFromPackage() 已认四个依赖键 → 只写在 optional/peer
 *      里的安装不会被列进清理名单（半卸载）。
 *   B. lib/redteam/index.js 的 dispose 只有 undeclare() → 停用后宿主的
 *      agent-preset-registry.selectedDefault 仍指向已消失的 redteam preset，
 *      resolve() 硬抛 agent-preset/not-found，每个工作区都建不出新会话。
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
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "dsh-purge-pr110-"));
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

async function main() {
  // ── A. pkgMentionsPurge 的四个依赖键 ────────────────────────────────
  await check("A1 optionalDependencies 里的安装会被列进清理名单", () => {
    const home = fixture((p) => writeProfile(p, "optional-only", { optionalDependencies: { "dsh-purge": "^1.2.3" } }));
    const found = listInstalledProfiles(home).map((x) => x.name);
    assert.ok(found.includes("optional-only"), `listInstalledProfiles 漏了 optional-only: ${JSON.stringify(found)}`);
  });

  await check("A2 peerDependencies 里的安装会被列进清理名单", () => {
    const home = fixture((p) => writeProfile(p, "peer-only", { peerDependencies: { "dsh-purge": "^1.2.3" } }));
    const found = listInstalledProfiles(home).map((x) => x.name);
    assert.ok(found.includes("peer-only"), `listInstalledProfiles 漏了 peer-only: ${JSON.stringify(found)}`);
  });

  await check("A3 dependencies / devDependencies 旧行为不回归", () => {
    const home = fixture((p) => {
      writeProfile(p, "dep", { dependencies: { "dsh-purge": "^1.2.3" } });
      writeProfile(p, "dev", { devDependencies: { "dsh-purge": "^1.2.3" } });
    });
    const found = listInstalledProfiles(home).map((x) => x.name).sort();
    assert.deepEqual(found, ["dep", "dev"]);
  });

  await check("A4 spec 从四个键里都能取到（不只 dependencies）", () => {
    const home = fixture((p) => {
      writeProfile(p, "opt", { optionalDependencies: { "dsh-purge": "1.1.71" } });
      writeProfile(p, "peer", { peerDependencies: { "dsh-purge": "1.1.72" } });
    });
    const specs = Object.fromEntries(listInstalledProfiles(home).map((x) => [x.name, x.spec]));
    assert.equal(specs.opt, "1.1.71");
    assert.equal(specs.peer, "1.1.72");
  });

  await check("A5 无关 profile 不被误列；空值不炸", () => {
    const home = fixture((p) => {
      writeProfile(p, "clean", { dependencies: { other: "1.0.0" } });
      writeProfile(p, "empty", {});
      fs.mkdirSync(path.join(p, "nopkg"), { recursive: true });
    });
    assert.deepEqual(listInstalledProfiles(home), []);
  });

  await check("A6 strip 与 mentions 四个键完全对齐", () => {
    for (const key of ["dependencies", "devDependencies", "optionalDependencies", "peerDependencies"]) {
      const pkg = { [key]: { "dsh-purge": "^1.2.3", other: "1.0.0" } };
      assert.equal(stripPluginFromPackage(pkg), true, `${key} strip 应命中`);
      assert.equal(Object.hasOwn(pkg[key], "dsh-purge"), false, `${key} strip 未删`);
      assert.equal(pkg[key].other, "1.0.0", `${key} 误删了别的依赖`);
      assert.equal(stripPluginFromPackage(pkg), false, `${key} strip 不幂等`);
    }
  });

  await check("A7 嵌套 dsh.profile.bundles/plugins 的提及判定不回归（1.1.81 已有）", () => {
    const home = fixture((p) => writeProfile(p, "nested", { dsh: { profile: { bundles: ["dsh-purge@1.2.3"] } } }));
    assert.equal(listInstalledProfiles(home)[0].name, "nested");
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
    const r = await releaseOwnDefault({
      registry: registryOf("standard", "standard"),
      settings: { update: () => { calls += 1; } },
    });
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

  await check("B3 settings 不可用 / fallback 为空或自指时只落状态，不写", async () => {
    for (const [selected, fallback, settings] of [
      ["redteam", "standard", null],
      ["redteam", "", { update: () => { throw new Error("不应被调用"); } }],
      ["redteam", "redteam", { update: () => { throw new Error("不应被调用"); } }],
    ]) {
      const r = await releaseOwnDefault({
        registry: registryOf(selected, fallback),
        settings,
        onStatus: (s) => assert.equal(s.phase, "release-default-skipped"),
      });
      assert.equal(r.action, "skipped", `selected=${selected} fallback=${fallback}`);
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
    for (const registry of [
      null,
      {},
      { config: { selectedDefault: { get: () => { throw new Error("no config"); } } } },
    ]) {
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
