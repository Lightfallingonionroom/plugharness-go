# plugins/

Bundled DSH plugins that are not part of the app's Flutter/native build.

- `dsh-purge-go/` — merged dsh-purge build for dsh-go (Android + proot), with the
  native Purge panel. Default choice.
- `dsh-purge-evans/` — Evans-repo- 1.1.71-rc2.1 (targets DSH 0.2.1-rc.2).
- `dsh-purge-real/` — realMisakaMikoto dsh-purge 1.2.3.

Switch between them:

```sh
tooling/switch-purge.sh go      # default merged build
tooling/switch-purge.sh evans
tooling/switch-purge.sh real
```

Plugins here are installed into a DSH profile at runtime; they are not compiled into
the APK. The app's plugin market only accepts npm packages, so these are installed
from the repository path.
