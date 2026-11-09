// Test-only Cordis plugin (issue #4) that throws during apply().
//
// The host must attribute the failure to this package and stay startable; it must not
// leave `dependencies` / `dsh.profile.bundles` half-written so the next boot cannot recover.
export const name = 'dsh-go-fixture-cordis-throws';

export function apply() {
  throw new Error('dsh-go fixture: deliberate init failure');
}
