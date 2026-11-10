# 本机 vs CI：什么时候用哪个

> 脚本：`tooling/local-fast-check.sh`
> 2026-11-10 在 arm64 机器上实测的数据

## 一句话

**本机做「判断」，CI 做「构建」。** 本机 5 秒能查的，别交给 14 分钟的 CI；
本机做不到的（Flutter），别假装做到了。

## 实测对比

| 动作 | 本机 | GitHub Actions |
|---|---|---|
| `dart analyze packages/dsh_client` | **1 秒**（含 pub get） | 排队 + 环境 ~2–3 分钟 |
| `dart analyze packages/dsh_remote` | **1 秒** | 同上 |
| `node --test` 离线套件（2 个） | **2 秒** | 3–5 分钟 |
| `runtime/build-runtime.sh arm64-v8a` | **205 秒**（缓存 257M） | **3.4 分钟** |
| Flutter pub get | ❌ 无 SDK | 0.3 分钟 |
| `flutter build apk`（Flutter 编译 + Gradle） | ❌ **做不到** | **8.9 分钟** |
| **出 APK 全流程** | ❌ | **14.0 分钟** |

`local-fast-check.sh` 全量实测：**5 秒**。

## 为什么本机打不了 APK

不是慢，是**打不了**：

1. Flutter 官方**不发 arm64 Linux 版**。`releases_linux.json` 里
   `architectures` 只有 `['x64']`。
2. x64 版在这台机器上跑不起来：`cannot execute: required file not found`。
3. 本机没有 `qemu-x86_64`，也没有 binfmt_misc → 没有用户态模拟这条路。

所以 `flutter analyze` / `flutter test` / `flutter build apk` 一律交 CI。

## runtime 构建：两边一样快

本机 205 秒 vs CI 3.4 分钟，基本持平。原因是这段是纯 IO + `xz` 压缩，
6 核对 4 核，差距被压缩算法吃掉了。

**结论：没必要把 runtime 搬到本机。** 把 runtime 产物从本机传给 CI 还要改
workflow、传 154M 文件，省不下时间。

但本机跑 runtime 有一个真实用途：**验证 runtime 相关改动**（补丁链、
`build-runtime.sh` 的修改）。跑一次 205 秒，比推上去等 14 分钟强。

## 日常怎么用

### 改 Dart 包 / 改文档 / 改脚本

```bash
tooling/local-fast-check.sh
```

5 秒。全绿再推。

### 改 runtime（补丁、build-runtime.sh）

```bash
# 1. 先快检
tooling/local-fast-check.sh

# 2. 真跑一遍 runtime 构建（205 秒）
runtime/build-runtime.sh arm64-v8a

# 3. 再推
```

> 注意：`build-runtime.sh` 里 `NODE_MIRROR` / `PBS_MIRROR` 默认指向
> `npmmirror.com`。这台机器连不上那个域（`SSL_ERROR_SYSCALL`），但
> `nodejs.org` 和 GitHub 都通。本机跑之前要临时改成本地副本：
>
> ```bash
> sed 's|^NODE_MIRROR=.*|NODE_MIRROR="https://nodejs.org/dist"|; \
>      s|^PBS_MIRROR=.*|PBS_MIRROR="https://github.com/astral-sh/python-build-standalone/releases/download"|' \
>   runtime/build-runtime.sh > runtime/.local-build-runtime.sh
> chmod +x runtime/.local-build-runtime.sh
> runtime/.local-build-runtime.sh arm64-v8a
> rm runtime/.local-build-runtime.sh
> ```
>
> 另外需要 `file` 命令做 ABI 校验（`apt-get install -y file`），否则会在
> 最后一步报 `ABI mismatch`。

### 改 Flutter（`app/lib/**`）

本机只能靠 `local-fast-check.sh` 里的 Dart 部分间接兜底，Flutter 侧必须推上去。
推之前最好人工过一遍：改动是否碰了 `appearance_page_test` /
`drawer_geometry_test` 这类几何契约测试。

### 出 APK

```bash
gh workflow run build-apk.yml --ref main
# 或直接问我
```

14 分钟。产物在 Actions artifacts，205 MB。

## 脚本会说什么、不会说什么

`local-fast-check.sh` 的输出分三档：

- `✓` 真跑过并且过了
- `✗` 真跑过并且挂了（退出码 1）
- `–` **没做**（环境不全）

第三档是重点：**「跳过」不等于「通过」**。脚本会写明为什么跳过
（没有 Flutter、没有 `DSH_PREFIX`、缺 `dsh-official-bundles`），
不让人误以为检查过了。

## 白名单为什么只有两个 node 套件

`runtime/tests` 有 **159** 个 `*.test.mjs`。全跑要几十分钟，而且大部分需要
一台活着的 bridge + engine。

白名单：

| 套件 | 为什么在 |
|---|---|
| `cordis-lifecycle.test.mjs` | 纯离线：起临时 profile、装/启/停/卸、删掉 |
| `boot-cache.test.mjs` | 纯离线：文件系统缓存层 |

**不在**白名单的：

| 套件 | 为什么不在 |
|---|---|
| `plugin-bundle-membership.test.mjs` | 需要 `@deepseek-ai/dsh-official-bundles`，裁剪过的 DSH 副本没有 |
| `plugin-config-bundles.test.mjs` | 同上 |
| 其余 155 个 | 需要活着的 host / bridge / engine |

## 已验证

2026-11-10，这台 arm64 机器：

```
$ tooling/local-fast-check.sh
...
  ✓ dsh_client analyze
  ✓ dsh_remote analyze
  ✓ runtime offline tests

本机能查的都过了。Flutter 侧（analyze / test / APK）仍然要 CI。
elapsed=5s
```