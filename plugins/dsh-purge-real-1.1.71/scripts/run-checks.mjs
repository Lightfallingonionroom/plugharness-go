#!/usr/bin/env node
/**
 * 1.1.71 基线的单入口回归：沿用社区 1.1.71 自带的宿主修复检查，
 * 加上从镜像存档 PR #110 移植过来的两处修复回归。
 *
 * 用法：node scripts/run-checks.mjs
 */
import { spawnSync } from "node:child_process";

const checks = [
  "check-40-and-hostfs.mjs",   // 1.1.71 自带：#40 rc.2 完整块 / hostFs 同步方法 / 备份 rename
  "check-pr110-ports.mjs",     // 移植：卸载四依赖键 + 嵌套 bundles + 停用交还默认预设
];

let failed = 0;
for (const file of checks) {
  const result = spawnSync(process.execPath, ["scripts/" + file], { stdio: "inherit", windowsHide: true });
  if (result.status !== 0) failed += 1;
}
if (failed) {
  console.error(`FAIL ${failed} 个检查脚本未通过`);
  process.exit(failed);
}
console.log("ALL PASS");
