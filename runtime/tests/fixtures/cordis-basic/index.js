// Test-only general Cordis plugin (issue #4).
//
// Deliberately does nothing: no tools, no routes, no file access, no network. Its only job
// is to prove the *ordinary* plugin lifecycle works end to end — that a plain
// bundle/Cordis package can be installed through the real plugin manager, appear in
// `dsh.profile.bundles`, load when `dsh web` boots, and disappear cleanly on uninstall.
//
// The native-plugin tests in run-native-tests.sh cover `dshGo` manifests loaded by path;
// this fixture is the other half of the story.
export const name = 'dsh-go-fixture-cordis-basic';

/** Set by apply() so a test can tell "loaded" from "installed but disabled". */
export let applied = false;

export function apply(ctx) {
  applied = true;
  // Register one inert service so the plugin has a real registration to dispose on
  // disable. A plugin that registers nothing would pass even if disposal were broken.
  ctx.provide?.('dshGoFixtureCordisBasic', { fixture: true });
  return () => {
    applied = false;
  };
}