const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeUsage,
  estimateWhisperTokenEquivalent,
  todayKey,
  monthKey,
} = require('./aiUsageTelemetry');

test('normalizeUsage sums prompt and completion when total missing', () => {
  const u = normalizeUsage({ prompt_tokens: 10, completion_tokens: 5 });
  assert.equal(u.prompt, 10);
  assert.equal(u.completion, 5);
  assert.equal(u.total, 15);
});

test('normalizeUsage keeps explicit total', () => {
  const u = normalizeUsage({ total_tokens: 99, prompt_tokens: 10 });
  assert.equal(u.total, 99);
});

test('estimateWhisperTokenEquivalent returns positive values', () => {
  const w = estimateWhisperTokenEquivalent(16000);
  assert.ok(w.seconds >= 1);
  assert.ok(w.tokenEquivalent >= 25);
});

test('todayKey and monthKey use yyyyMMdd / yyyyMM format', () => {
  const d = new Date('2026-05-26T12:00:00.000Z');
  assert.match(todayKey(d), /^\d{8}$/);
  assert.match(monthKey(d), /^\d{6}$/);
});
