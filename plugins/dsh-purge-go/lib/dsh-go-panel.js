// dsh-go 原生面板：全部功能 › 插件面板（Purge）。
// 视图结构参考 dsh-purge-go v0.3.2，状态/操作适配优化版内核（lib/core.js）。
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import * as core from './core.js'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const BIN = path.join(HERE, '..', 'bin', 'dsh-purge.js')
const CACHE = (home) => path.join(home, 'dsh-purge', 'dsh-go-status.json')

const KB = (bytes) => `${(bytes / 1024).toFixed(1)} KB`

/** 提示词注入层现场（轻量、同步）。 */
function readSnap(home, config) {
  const injectPath = path.join(home, 'prompt-inject.md')
  let bytes = 0
  let chars = 0
  try {
    const text = fs.readFileSync(injectPath, 'utf8')
    bytes = Buffer.byteLength(text, 'utf8')
    chars = text.length
  } catch {
    /* 文件不存在时按 0 显示 */
  }
  return {
    enabled: config?.enabled !== false,
    injectPath,
    bytes,
    chars,
    sourceLabel: 'prompt-inject.md',
    variant: '默认',
    last: {},
    extra: { ranges: { v4: 0, v6: 0 }, target: '', cardBytes: 0 },
    byModel: {},
    variants: [],
  }
}

/** 补丁层现场：读缓存；缓存由 updatePatchCache() 后台刷新。 */
function readPatchCache(home) {
  try {
    return JSON.parse(fs.readFileSync(CACHE(home), 'utf8'))
  } catch {
    return { ok: false, error: '正在读取宿主状态…' }
  }
}

/** 跑一次只读 status，把补丁分布写进缓存。 */
function updatePatchCache(home) {
  const file = CACHE(home)
  try {
    const out = execFileSync(process.execPath, [BIN, '--status', '--json'], {
      env: { ...process.env, DSH_HOME: home },
      timeout: 30000,
      stdio: ['ignore', 'pipe', 'ignore'],
    })
    const state = JSON.parse(out.toString('utf8'))
    const layers = {}
    for (const p of core.ALL_PATCHES) {
      const st = state.patch_status?.[String(p.id)] || 'na'
      const layer = p.layer || '其他'
      layers[layer] = layers[layer] || { applied: 0, skipped: 0, na: 0 }
      if (st === 'applied') layers[layer].applied += 1
      else if (st === 'na') layers[layer].na += 1
      else layers[layer].skipped += 1
    }
    const summary = {
      ok: true,
      aiBase: state.ai_base || '',
      applied: state.patches_applied || 0,
      pending: state.patches_pending || 0,
      skipped: state.patches_skipped || 0,
      na: state.patches_na || 0,
      total: state.patches_total || 0,
      has_backup: !!state.has_backup,
      activation: state.patches_active ? 'active' : 'inactive',
      layers,
      at: new Date().toISOString(),
    }
    fs.mkdirSync(path.dirname(file), { recursive: true })
    fs.writeFileSync(file, JSON.stringify(summary, null, 2))
  } catch (error) {
    const summary = { ok: false, error: String(error?.message || error), at: new Date().toISOString() }
    try {
      fs.mkdirSync(path.dirname(file), { recursive: true })
      fs.writeFileSync(file, JSON.stringify(summary, null, 2))
    } catch {
      /* 写不进就算了 */
    }
  }
}

function layerRows(layers, z) {
  return Object.entries(layers || {}).map(([layer, c]) => [
    layer,
    String(c.applied || 0),
    String(c.skipped || 0),
    String(c.na || 0),
  ])
}

/** 面板视图：状态 / 提示词 / 补丁 三个 tab。 */
export function panelView(snap, patch, caps) {
  const locale = caps?.locale === 'en' ? 'en' : 'zh'
  const z = (zh, en) => (locale === 'en' ? en : zh)
  const patchOk = patch?.ok
  const patchApplied = patch?.applied ?? 0
  const patchTotal = patch?.total ?? 85
  const patchNa = patch?.na ?? 0
  const patchSkipped = patch?.skipped ?? 0
  const patchPending = patch?.pending ?? 0

  const statusChildren = [
    {
      type: 'row',
      children: [
        { type: 'metric', label: z('状态', 'State'), value: snap.enabled ? z('开', 'on') : z('关', 'off'), tone: snap.enabled ? 'good' : 'warn' },
        { type: 'metric', label: z('正文', 'Prompt'), value: KB(snap.bytes), caption: `${snap.chars} ${z('字', 'chars')}` },
        {
          type: 'metric',
          label: z('补丁', 'Patches'),
          value: `${patchApplied}/${patchTotal}`,
          tone: patchApplied > 0 ? 'good' : 'bad',
          caption: patchPending ? z(`${patchPending} 条待应用`, `${patchPending} pending`) : z('无待应用项', 'none pending'),
        },
      ],
    },
    {
      type: 'keyValue',
      items: [
        [z('来源', 'Source'), snap.sourceLabel],
        [z('变体', 'Variant'), snap.variant],
        [z('主文件', 'File'), snap.injectPath],
        [z('备份', 'Backup'), patch?.has_backup ? z('在位', 'ready') : z('无', 'none')],
      ],
    },
    {
      type: 'actions',
      items: [
        { label: z('应用', 'Apply'), action: { id: 'apply' }, style: 'primary' },
        { label: z('还原', 'Revert'), action: { id: 'revert' }, style: 'plain' },
        { label: z('刷新', 'Refresh'), action: { id: 'refresh' }, style: 'plain' },
        { label: z('卸载', 'Uninstall'), action: { id: 'uninstall' }, style: 'plain' },
      ],
    },
    {
      type: 'callout',
      text: z('补丁层已写入磁盘；重启引擎后生效。', 'Patches are on disk; restart the engine to apply.'),
      tone: 'warn',
    },
  ]

  const promptChildren = [
    {
      type: 'keyValue',
      items: [
        [z('主文件', 'File'), snap.injectPath],
        [z('字节', 'Bytes'), String(snap.bytes)],
        [z('字符', 'Chars'), String(snap.chars)],
        [z('来源', 'Source'), snap.sourceLabel],
      ],
    },
    {
      type: 'actions',
      items: [
        { label: z('复制正文', 'Copy prompt'), action: { id: 'copy' }, style: 'plain' },
        { label: z('刷新', 'Refresh'), action: { id: 'refresh' }, style: 'plain' },
      ],
    },
  ]

  const patchChildren = patchOk
    ? [
        {
          type: 'keyValue',
          items: [
            [z('已生效', 'Applied'), String(patchApplied)],
            [z('待清洗', 'Pending'), String(patchPending)],
            [z('跳过/缺失', 'Skipped'), String(patchSkipped)],
            [z('不适用', 'N/A'), String(patchNa)],
            [z('宿主', 'Host'), patch.aiBase || '-'],
          ],
        },
        {
          type: 'table',
          columns: [z('层', 'Layer'), z('已生效', 'Applied'), z('跳过', 'Skipped'), z('不适用', 'N/A')],
          rows: layerRows(patch.layers, z),
        },
      ]
    : [
        { type: 'callout', text: z('正在读取宿主状态…', 'Reading host status…'), tone: 'info' },
      ]

  return {
    v: 2,
    type: 'tabs',
    title: 'Purge',
    items: [
      { label: z('状态', 'Status'), children: statusChildren },
      { label: z('提示词', 'Prompt'), children: promptChildren },
      { label: z('补丁', 'Patches'), children: patchChildren },
    ],
  }
}

async function applyPatches() {
  core.applyRuntimeEnv()
  const state = await core.gatherState()
  if (!state.ai_base) throw new Error('未找到宿主')
  await core.applyPatchesAllHosts(core.ALL_PATCHES, { preserveClientBundles: false, forApply: true })
  await core.patchAllShims()
}

async function revertPatches() {
  const state = await core.gatherState()
  if (state.ai_base) await core.revertAll(state.ai_base)
  await core.revertAllShims()
}

/**
 * 注册原生面板。
 * @param {any} ctx 已 inject(['dshGo']) 的 ctx
 * @param {{ home: string, config: any, warn: (message: string) => void }} deps
 */
export function installNative(ctx, deps) {
  const { home, config, warn } = deps
  const bridge = ctx && ctx.dshGo
  if (!bridge || typeof bridge !== 'object') return false

  const snap = () => readSnap(home, config)
  const patch = () => readPatchCache(home)
  const bump = () => {
    try {
      bridge.refresh?.('purge')
    } catch {
      /* 旧桥接没有 refresh，忽略 */
    }
  }
  const guarded = (label, fn) => async (...args) => {
    try {
      return await fn(...args)
    } catch (error) {
      warn(`dsh-go ${label}: ${error?.message || error}`)
      return { toast: '操作失败' }
    }
  }

  try {
    if (typeof bridge.panel === 'function') {
      bridge.panel('purge', {
        view: (scope, caps) => panelView(snap(), patch(), caps),
        actions: {
          apply: guarded('apply', async () => {
            await applyPatches()
            updatePatchCache(home)
            bump()
            return { toast: '清洗完成，重启引擎生效' }
          }),
          revert: guarded('revert', async () => {
            await revertPatches()
            updatePatchCache(home)
            bump()
            return { toast: '已回滚，重启引擎恢复' }
          }),
          refresh: guarded('refresh', async () => {
            updatePatchCache(home)
            bump()
            return { toast: '已刷新' }
          }),
          copy: guarded('copy', async () => {
            const text = fs.readFileSync(path.join(home, 'prompt-inject.md'), 'utf8')
            return [
              { type: 'copy', text },
              { type: 'toast', text: '已复制正文' },
            ]
          }),
          uninstall: guarded('uninstall', async () => ({ toast: '请在大厅插件页卸载' })),
        },
      })
    }
  } catch (error) {
    warn(`面板注册失败：${error?.message || error}`)
  }

  // 首次读状态 + 每 60 秒刷新一次缓存。
  void Promise.resolve(updatePatchCache(home)).then(bump)
  const timer = setInterval(() => {
    void Promise.resolve(updatePatchCache(home)).then(bump)
  }, 60_000)
  try {
    ctx.effect?.(() => () => clearInterval(timer))
  } catch {
    /* 无 effect 时靠 cordis scope 自己回收 */
  }
  return true
}
