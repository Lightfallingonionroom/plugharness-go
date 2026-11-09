// Behaviour test for the assistant-stream shape patch (issue #1).
//
// Runs against the patched dsh-llm from /tmp/verify. Checks the four promises the issue
// makes: malformed events do not escape, valid events are untouched and ordered, an
// unknown-after-valid stream keeps going, and the diagnostic carries no user content.
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// CI sets DSH_PREFIX; the patched dsh-llm lives under it after runtime/patches is applied.
const prefix = process.env.DSH_PREFIX;
if (!prefix) {
  console.log('skip: DSH_PREFIX is not set');
  process.exit(0);
}
const { AssistantStreamAccumulator } = await import(
  pathToFileURL(resolve(prefix, 'node_modules/@deepseek-ai/dsh-llm/lib/index.js')).href,
);

const results = [];
function check(name, fn) {
  try {
    fn();
    results.push(['ok', name]);
  } catch (error) {
    results.push(['FAIL', name, error.message]);
  }
}
function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

let diags = [];
function captureDiagnostics() {
  diags = [];
  globalThis[Symbol.for('dsh.assistantStreamDiagnostics')] = (d) => diags.push(d);
}

// A valid stream still accumulates exactly as before: text delta joined, order preserved.
check('valid text deltas still accumulate in order', () => {
  captureDiagnostics();
  const a = new AssistantStreamAccumulator();
  a.push({ time: 1, chunk: { type: 'text-delta', index: 0, text: 'hello ' } });
  a.push({ time: 2, chunk: { type: 'text-delta', index: 0, text: 'world' } });
  const snap = a.snapshot();
  assert(snap.length === 1, `expected one compacted record, got ${snap.length}`);
  assert(snap[0].type === 'text-chunks', `expected text-chunks, got ${snap[0].type}`);
  assert(snap[0].texts.join('') === 'hello world', `text mismatch: ${snap[0].texts.join('')}`);
  assert(diags.length === 0, `no diagnostics expected, got ${diags.length}`);
});

// An unknown chunk type is dropped, recorded, and does NOT throw.
check('unknown chunk type is isolated, not thrown', () => {
  captureDiagnostics();
  const a = new AssistantStreamAccumulator();
  let threw = null;
  try {
    a.push({ time: 1, chunk: { type: 'totally-new-kind', index: 0 } });
  } catch (error) {
    threw = error;
  }
  assert(threw === null, `push must not throw, but threw: ${threw && threw.message}`);
  assert(diags.length === 1, `expected one diagnostic, got ${diags.length}`);
  assert(diags[0].kind === 'assistant-stream/malformed-chunk', `kind: ${diags[0].kind}`);
  assert(diags[0].declaredType === 'totally-new-kind', `declaredType: ${diags[0].declaredType}`);
  assert(diags[0].stage === 'AssistantStreamAccumulator.push', `stage: ${diags[0].stage}`);
});

// The diagnostic must not leak the payload.
check('diagnostic carries no chunk body', () => {
  captureDiagnostics();
  const a = new AssistantStreamAccumulator();
  a.push({ time: 1, chunk: { type: 'evil', secret: 'sk-live-DEADBEEF', prompt: 'my private question' } });
  const json = JSON.stringify(diags[0]);
  assert(!json.includes('sk-live-DEADBEEF'), 'diagnostic leaked an API key');
  assert(!json.includes('my private question'), 'diagnostic leaked user text');
  assert(json.includes('secret') && json.includes('prompt'), 'field NAMES should be listed');
});

// A bad frame in the middle must not swallow the rest of the stream.
check('a malformed frame in the middle keeps later frames', () => {
  captureDiagnostics();
  const a = new AssistantStreamAccumulator();
  a.push({ time: 1, chunk: { type: 'text-delta', index: 0, text: 'before ' } });
  a.push({ time: 2, chunk: { type: 'nonsense', index: 99 } });
  a.push({ time: 3, chunk: { type: 'text-delta', index: 0, text: 'after' } });
  const snap = a.snapshot();
  const text = snap.filter(r => r.type === 'text-chunks').map(r => r.texts.join('')).join('');
  assert(text === 'before after', `text after recovery: ${JSON.stringify(text)}`);
  assert(diags.length === 1, `expected one diagnostic, got ${diags.length}`);
});

// A non-serialisable chunk (circular) used to throw from snapshotChunk.
check('a circular chunk is isolated, not thrown', () => {
  captureDiagnostics();
  const a = new AssistantStreamAccumulator();
  const circular = { type: 'text-delta', index: 0, text: 'x' };
  circular.self = circular;
  let threw = null;
  try {
    a.push({ time: 1, chunk: circular });
  } catch (error) {
    threw = error;
  }
  assert(threw === null, `push must not throw on a circular chunk, threw: ${threw && threw.message}`);
  assert(diags.length === 1, `expected one diagnostic, got ${diags.length}`);
  assert(String(diags[0].reason).includes('not JSON-serializable'), `reason: ${diags[0].reason}`);
});

// Wrong field types on a known chunk keep the original strictness: that is a contract
// violation the accumulator can still describe, and the issue only asks that the *host*
// survives — a text-delta with a non-string text is still a bug worth surfacing.
check('a known chunk with the wrong field type still reports itself', () => {
  captureDiagnostics();
  const a = new AssistantStreamAccumulator();
  let caught = null;
  try {
    a.push({ time: 1, chunk: { type: 'text-delta', index: 0, text: 42 } });
  } catch (error) {
    caught = error;
  }
  assert(caught !== null, 'a wrong-typed known chunk is still a programming error');
  assert(/text must be a string/.test(caught.message), `message: ${caught.message}`);
});

const failed = results.filter(r => r[0] === 'FAIL');
for (const [status, name, detail] of results) {
  console.log(`${status.padEnd(4)} ${name}${detail ? ' — ' + detail : ''}`);
}
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);