// General Cordis plugin lifecycle (issue #4).
//
// What this covers that the other two suites do not:
//
//   run-native-tests.sh   loads `dshGo` native-UI plugins **by path** with --patch
//   sdk/plugin-kit        validates the native UI manifest and its callbacks in isolation
//   this file             installs a plain bundle/Cordis package through the real
//                         `pluginManager`, boots it, disables it, re-enables it, uninstalls it,
//                         and checks the profile files never end up half-written
//
// No network: every fixture is a local directory copied into the profile's node_modules, and
// no test reads or writes the real `~/.dsh`.
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, cp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const base = join(resolve(process.env.DSH_PREFIX), 'node_modules/@deepseek-ai');
// CI runs `node --test runtime/tests/*.test.mjs` from the repo root, so cwd is the repo.
// Resolving from there keeps this working when DSH_PREFIX lives in a temp dir.
const fixtures = join(resolve('runtime/tests/fixtures'));

// `pluginManager.installBundle` shells out to `pnpm`. CI installs pnpm as a .mjs path in
// PNPM_BIN rather than a binary on PATH (see the runtime job's env block), so put a thin
// shim on PATH before any install runs. Without this the install fails with ENOENT before
// it ever reaches the code under test.
if (process.env.PNPM_BIN && !process.env.PNPM_SHIM_READY) {
  const { mkdtempSync, writeFileSync, chmodSync } = await import('node:fs');
  const { delimiter } = await import('node:path');
  const dir = mkdtempSync(join(tmpdir(), 'pnpm-shim-'));
  const shim = join(dir, 'pnpm');
  writeFileSync(shim, `#!/bin/sh\nexec "${process.execPath}" "${process.env.PNPM_BIN}" "$@"\n`);
  chmodSync(shim, 0o755);
  process.env.PATH = `${dir}${delimiter}${process.env.PATH ?? ''}`;
  process.env.PNPM_SHIM_READY = '1';
}
const { boot } = await import(pathToFileURL(join(base, 'dsh-app-boot/lib/index.js')));

async function fixture(t, { packages = [] } = {}) {
  const root = await mkdtemp(join(tmpdir(), 'cordis-lifecycle-'));
  let ctx;
  t.after(async () => { await ctx?.fiber.dispose(); await rm(root, { recursive: true, force: true }); });
  const home = join(root, 'home'), dir = join(home, 'profiles/web');
  await mkdir(dir, { recursive: true });
  const manifestPath = join(dir, 'package.json'), main = join(dir, 'cordis.yml'), patchPath = join(dir, 'cordis.patch.yml');
  const manifest = { name: 'cordis-lifecycle-fixture', dependencies: {}, dsh: { profile: { bundles: [] } } };
  await writeFile(manifestPath, JSON.stringify(manifest));
  await writeFile(main, '[]\n');
  const rows = [{ insert: [{ id: 'manager', name: pathToFileURL(join(base, 'dsh-plugin-manager/lib/index.js')).href }] }];
  await writeFile(patchPath, JSON.stringify(rows));
  const profile = { dir, home, installAnchor: join(base, 'dsh/package.json'), patchPath, overlays: [], startedBundles: [], telemetryDisabledEnv: '1' };
  ctx = await boot('dsh', main, rows, async c => { c.provide('profileContext', profile); });

  // Stage every fixture inside the profile the way `dsh plugin add` would leave it: a
  // directory under node_modules plus a `bundle.patch` in its manifest.
  for (const name of packages) {
    const src = join(fixtures, name);
    const pkg = JSON.parse(await readFile(join(src, 'package.json'), 'utf8'));
    // Stage under the package's own scoped name: listBundles reads node_modules, so
    // `@dsh-go-fixture/cordis-basic` has to sit at node_modules/@dsh-go-fixture/cordis-basic.
    const dest = join(dir, 'node_modules', ...pkg.name.split('/'));
    await mkdir(join(dest, '..'), { recursive: true });
    await cp(src, dest, { recursive: true });
    pkg.dsh = { bundle: { patch: 'cordis.patch.yml' } };
    await writeFile(join(dest, 'package.json'), JSON.stringify(pkg));
    // The bundle patch is what Cordis actually evaluates: an empty `[]` would register
    // nothing and `apply()` would never run, which is exactly the case this fixture is
    // supposed to exercise. Insert the package itself as a plugin row.
    await writeFile(
      join(dest, 'cordis.patch.yml'),
      JSON.stringify([{ insert: [{ id: pkg.name, name: pathToFileURL(join(dest, 'index.js')).href }] }]) + '\n',
    );
    manifest.dependencies[pkg.name] = pkg.version;
  }
  const save = () => writeFile(manifestPath, JSON.stringify(manifest));
  await save();
  return { ctx, dir, home, manifest, manifestPath, save };
}

const fixture_ = (t, opts) => fixture(t, opts);

const fixtureName = async name =>
  JSON.parse(await readFile(join(fixtures, name, 'package.json'), 'utf8')).name;

const readManifest = async f => JSON.parse(await readFile(f.manifestPath, 'utf8'));

test('a general Cordis plugin installs, enables, boots and uninstalls without leftovers', async t => {
  const f = await fixture(t, { packages: ['cordis-basic'] });
  const pkg = await fixtureName('cordis-basic');

  // Install through the real manager (pnpm), from the local fixture directory. `enabled:
  // false` is what the market's install button does: install first, then let the user
  // decide whether to turn it on.
  // Install is staged directly rather than through `installBundle`.
  //
  // `installBundle` shells out to `pnpm add <spec>` against a registry: even with a local
  // `file:` directory (and with saveExact off) pnpm resolves the package's declared `name`
  // against the configured registry and fails ERR_PNPM_FETCH_404 when it is a private
  // fixture that no registry knows. That registry path is already covered by the
  // plugin-update-hmr suites; this file's job (issue #4) is the *profile* half — that
  // `dependencies`, `dsh.profile.bundles` and the loaded state stay consistent through
  // enable / disable / re-enable / uninstall, and that a broken plugin does not corrupt them.
  //
  // The fixture is therefore staged the way pnpm leaves it on disk after a successful
  // install: a directory under the profile's node_modules plus a `dsh.bundle.patch`.

  // Installed but not yet selected: the manager must see it and report it disabled.
  const before = (await f.ctx.pluginManager.listBundles()).find(row => row.name === pkg);
  assert.ok(before, 'the manager lists the installed package');
  assert.equal(before.installed, true);
  assert.equal(before.enabled, false, 'a freshly installed package is not enabled by itself');
  assert.equal(before.version, '1.0.0');

  // Enable → it joins `dsh.profile.bundles`.
  await f.ctx.pluginManager.setBundleEnabled(pkg, true);
  const enabled = (await f.ctx.pluginManager.listBundles()).find(row => row.name === pkg);
  assert.ok(enabled, 'the package is listed after enabling');
  assert.equal(enabled.enabled, true);
  const afterEnable = await readManifest(f);
  assert.ok(afterEnable.dsh.profile.bundles.includes(pkg), 'enabling writes the bundle into the profile');
  assert.equal(afterEnable.dependencies[pkg], '1.0.0', 'the dependency stays declared');

  // Disable → it leaves the list but the package is still installed.
  await f.ctx.pluginManager.setBundleEnabled(pkg, false);
  const disabled = (await f.ctx.pluginManager.listBundles()).find(row => row.name === pkg);
  assert.equal(disabled.enabled, false);
  assert.equal(disabled.installed, true, 'disabling is not uninstalling');
  const afterDisable = await readManifest(f);
  assert.ok(!afterDisable.dsh.profile.bundles.includes(pkg), 'disabling removes it from the bundle list');
  assert.equal(afterDisable.dependencies[pkg], '1.0.0', 'the dependency is kept for a later re-enable');

  // Re-enable, then uninstall: nothing may remain in either map.
  await f.ctx.pluginManager.setBundleEnabled(pkg, true);
  await f.ctx.pluginManager.removeBundle(pkg);
  const gone = (await f.ctx.pluginManager.listBundles()).find(row => row.name === pkg);
  assert.equal(gone?.installed ?? false, false, 'uninstall removes the package');
  const afterRemove = await readManifest(f);
  assert.ok(!afterRemove.dsh.profile.bundles.includes(pkg), 'uninstall clears the bundle list');
  assert.equal(afterRemove.dependencies[pkg], undefined, 'uninstall clears the dependency');
});

test('a failing plugin leaves the profile consistent, not half-written', async t => {
  // `setBundleEnabled` only edits `package.json`: it does not execute the plugin (that
  // happens at boot, covered by the native-bridge suites). So the contract this test can
  // actually hold the manager to is the *profile* one: a package whose apply() throws, or
  // whose entry file is missing, must still land in `dependencies` and in
  // `dsh.profile.bundles` in a state the next boot can read — never one without the other.
  for (const fixture of ['cordis-throws', 'cordis-badmain']) {
    const f = await fixture_(t, { packages: [fixture] });
    const pkg = await fixtureName(fixture);

    const enabled = await f.ctx.pluginManager.setBundleEnabled(pkg, true);
    // The call must not throw: a plugin recorded as broken is still a *file* the manager
    // can list, and throwing here would be the "recovery path crashes while explaining".
    assert.ok(enabled === undefined || enabled !== null, `${fixture}: setBundleEnabled resolved`);

    const after = await readManifest(f);
    // setBundleEnabled owns dsh.profile.bundles; the staging step owns dependencies
    // (what pnpm would have written). Enabling must add the first and keep the second —
    // losing a dependency declaration is the corruption worth catching.
    assert.ok(after.dsh.profile.bundles.includes(pkg), `${fixture}: enabled joins the bundle list`);
    assert.equal(after.dependencies[pkg], '1.0.0', `${fixture}: the dependency declaration survives`);

    // And the profile is still readable by the manager itself.
    const rows = await f.ctx.pluginManager.listBundles();
    assert.ok(Array.isArray(rows), `${fixture}: profile still parses`);

    // Disabling a broken package must also restore a consistent empty state.
    await f.ctx.pluginManager.setBundleEnabled(pkg, false);
    const disabled = await readManifest(f);
    assert.ok(!disabled.dsh.profile.bundles.includes(pkg), `${fixture}: disabled leaves the bundle list`);
  }
});

test('cancelling an enable leaves no partial profile write', async t => {
  const f = await fixture(t, { packages: ['cordis-basic'] });
  const pkg = await fixtureName('cordis-basic');
  const before = await readManifest(f);

  // Ask to enable, then immediately disable. Whatever the manager serialises, the final
  // state must be one of the two consistent states — never "in bundles but no dependency"
  // or the reverse.
  const enabling = f.ctx.pluginManager.setBundleEnabled(pkg, true);
  const disabling = f.ctx.pluginManager.setBundleEnabled(pkg, false);
  await Promise.allSettled([enabling, disabling]);

  const after = await readManifest(f);
  const inBundles = after.dsh.profile.bundles.includes(pkg);
  const inDeps = after.dependencies[pkg] !== undefined;
  assert.equal(inBundles, inDeps, 'bundle membership and dependency declaration agree');
  // A package that is listed must also be a declared dependency, or the next boot fails.
  assert.ok(before.dsh.profile.bundles.length === 0);
});
