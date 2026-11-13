# plugins/

Bundled DSH plugins that are not part of the app's Flutter/native build.

- `dsh-purge-go/` — merged dsh-purge build for dsh-go (Android + proot). See its
  `README.md` and `GO-NOTES.md`; install with `tooling/install-purge-go.sh`.

Plugins here are installed into a DSH profile at runtime; they are not compiled into
the APK. The app's plugin market only accepts npm packages, so these are installed
from the repository path.
