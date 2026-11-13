// dsh-go 原生工具卡：把工具输出挂成 App 能画的视图。
// 与 dsh-purge-go 的 card.js 同构：任何异常、超预算、非无损 JSON 一律退化成「没有卡」，
// 绝不让一次工具调用因为画图失败而整体报错。
export const VIEW_KEY = 'dsh-go/view'
export const CARD_MAX_BYTES = 8 * 1024

export function toLosslessJson(value) {
  let text
  try {
    text = JSON.stringify(value)
  } catch {
    return undefined
  }
  return text === undefined ? undefined : JSON.parse(text)
}

export function jsonBytes(value) {
  const text = JSON.stringify(value)
  return text === undefined ? 0 : Buffer.byteLength(text, 'utf8')
}

/**
 * @param {(args: any, value: any) => any} build
 * @param {{ maxBytes?: number, onError?: (error: unknown) => void }} [options]
 */
export function toolCard(build, options = {}) {
  const maxBytes = options.maxBytes ?? CARD_MAX_BYTES
  return (args, value) => {
    try {
      const view = toLosslessJson(build(args, value))
      if (view === undefined || view === null) return {}
      if (jsonBytes(view) > maxBytes) {
        options.onError?.(new RangeError(`tool card is ${jsonBytes(view)} bytes, over ${maxBytes}`))
        return {}
      }
      return { [VIEW_KEY]: view }
    } catch (error) {
      options.onError?.(error)
      return {}
    }
  }
}

/** 最简单的文本卡：状态/结果文本。 */
export function textCard(text) {
  return { type: 'text', text: String(text ?? '') }
}
