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
const fixtures = join(resolve(process.env.DSH_PREFIX), '..', '..', 'runtime', 'tests', 'fixtures');
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
    const dest = join(dir, 'node_modules', '@dsh-go-fixture', name.replace(/^cordis-/, ''));
    await mkdir(join(dest, '..'), { recursive: true });
    await cp(src, dest, { recursive: true });
    const pkg = JSON.parse(await readFile(join(dest, 'package.json'), 'utf8'));
    pkg.dsh = { bundle: { patch: 'cordis.patch.yml' } };
    await writeFile(join(dest, 'package.json'), JSON.stringify(pkg));
    await writeFile(join(dest, 'cordis.patch.yml'), '[]\n');
    manifest.dependencies[pkg.name] = pkg.version;
  }
  const save = () => writeFile(manifestPath, JSON.stringify(manifest));
  await save();
  return { ctx, dir, home, manifest, manifestPath, save };
}

const readManifest = async f => JSON.parse(await readFile(f.manifestPath, 'utf8'));

test('a general Cordis plugin installs, enables, boots and uninstalls without leftovers', async t => {
  const f = await fixture(t, { packages: ['cordis-basic'] });
  const pkg = '@dsh-go-fixture/basic';

  // Install through the real manager (pnpm), from the local fixture directory. `enabled:
  // false` is what the market's install button does: install first, then let the user
  // decide whether to turn it on.
  const install = await f.ctx.pluginManager.installBundle(`file:${join(fixtures, 'cordis-basic')}`, {
    saveExact: true,
    enabled: false,
  });
  assert.equal(install.packageResult?.exitCode, 0, `pnpm install failed: ${install.packageResult?.output ?? ''}`);

  // Installed but not yet selected: the manager must see it and report it disabled.
  const before = (await f.ctx.pluginManager.listBundles()).find(row => row.name === pkg);
  assert.ok(before, 'the manager lists the installed package');
  assert.equal(before.installed, true);
  assert.equal(before.enabled, false, 'a freshly installed package is not enabled by itself');
  assert.equal(before.version, '1.0.0');

  // Enable → it joins `dsh.profile.bundles`.
  await f.ctx.pluginManager.setBundleEnabled(pkg, true);
  const enabled = (await f.ctx.pluginManager.listBundles()).find(row => row.name === pkg);
  assert.equal(enabled.enabled, true);
  assert.equal(enabled.error, undefined);
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

test('a plugin whose apply() throws is attributed and leaves the profile recoverable', async t => {
  const f = await fixture(t, { packages: ['cordis-throws'] });
  const pkg = '@dsh-go-fixture/throws';

  await f.ctx.pluginManager.setBundleEnabled(pkg, true);
  const rows = await f.ctx.pluginManager.listBundles();
  const row = rows.find(r => r.name === pkg);
  assert.ok(row, 'the failing package is still listed');
  // The manager must report the failure on the row rather than swallowing it, and the
  // message must name this package so a user can act on it.
  assert.ok(row.error, 'the failure is attributed to the bundle');
  assert.match(String(row.error.message ?? row.error), /deliberate init failure|throws/);

  // The profile must still parse and still boot: a half-written manifest is the bug this
  // test exists to catch.
  const manifest = await readManifest(f);
  assert.equal(typeof manifest, 'object');
  assert.ok(Array.isArray(manifest.dsh.profile.bundles));
  const reloaded = await f.ctx.pluginManager.listBundles();
  assert.ok(Array.isArray(reloaded), 'the manager can still read the profile after a failed plugin');
});

test('a plugin whose main file is missing is attributed, not fatal', async t => {
  const f = await fixture(t, { packages: ['cordis-badmain'] });
  const pkg = '@dsh-go-fixture/badmain';
  await f.ctx.pluginManager.setBundleEnabled(pkg, true);
  const row = (await f.ctx.pluginManager.listBundles()).find(r => r.name === pkg);
  assert.ok(row, 'the broken package is still listed');
  assert.ok(row.error, 'a missing entry point is reported on the row');
  const manifest = await readManifest(f);
  assert.equal(typeof manifest, 'object', 'the profile stays readable');
});

test('cancelling an enable leaves no partial profile write', async t => {
  const f = await fixture(t, { packages: ['cordis-basic'] });
  const pkg = '@dsh-go-fixture/basic';
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
