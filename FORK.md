# PlugHarness Go

Modified fork of [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go), maintained privately.

## Branches

| Branch | Purpose | Rule |
|---|---|---|
| `dsh-go` | Exact mirror of upstream `main` | Only fast-forward from upstream. Never commit here. |
| `main` | Our modified app | All our changes land here. Merge `dsh-go` in to take upstream updates. |

Upstream base at fork time: `45e1a7d0a8013e4dc90a5c3a7a19d990ac3d3ee8` (DSH Go 1.0.11 era, 2026-11-05).

## Taking upstream updates

```bash
git fetch upstream main
git checkout dsh-go && git merge --ff-only upstream/main && git push origin dsh-go
git checkout main && git merge dsh-go
```

## License and branding

- Code: AGPL-3.0 (inherited). `sdk/` and `examples/` stay MIT. Keep all copyright and license notices.
- Distributing a modified APK to anyone obliges us to offer the corresponding source under AGPL-3.0.
- The DSH Go name, logo, Deepy and whale-girl artwork are **not** covered by AGPL (see `ASSETS.md`).
  Replace them with our own name and artwork before giving the app to anyone else.
- Upstream asks forks to credit `https://github.com/ccch1mneyyy/dsh-go` and author `ccch1mneyyy`
  in the repo, the About page and release notes, and to contact the author before publishing a derivative.

## Inherited automation

`.github/workflows/ci.yml` and `pr-gate.yml` came from upstream and are **disabled in this repo's
Actions settings** (files left unchanged). Re-enable `ci.yml` only when we want CI minutes spent.
