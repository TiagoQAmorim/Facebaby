const assert = require('assert');
const {
  formatHistoryForPrompt,
  MAX_AI_HISTORY,
  MAX_PROMPT_AI_HISTORY,
} = require('./aiProfile');
const { buildAiNannyUserPrompt } = require('./prompts/aiNannyPrompt');

function testFormatHistoryForPrompt() {
  const short =
    'Minha bebê nasceu prematura de 34 semanas e tem refluxo.';
  assert.strictEqual(formatHistoryForPrompt(short), short);

  const long = 'a'.repeat(MAX_AI_HISTORY);
  const truncated = formatHistoryForPrompt(long);
  assert.ok(truncated.length <= MAX_PROMPT_AI_HISTORY + 1);
  assert.ok(truncated.endsWith('…'));

  assert.strictEqual(formatHistoryForPrompt(''), '');
  assert.strictEqual(formatHistoryForPrompt('  '), '');
}

function testPromptIncludesHistory() {
  const history =
    'Minha bebê nasceu prematura de 34 semanas e tem refluxo.';
  const prompt = buildAiNannyUserPrompt({
    question: 'Ela está chorando muito depois de mamar, o que pode ser?',
    contextBlock: 'Nome: Bebê\nSexo: menina',
    familyHistoryBlock: formatHistoryForPrompt(history),
  });

  assert.ok(prompt.includes('prematura'));
  assert.ok(prompt.includes('refluxo'));
  assert.ok(prompt.includes('chorando muito depois de mamar'));
  assert.ok(prompt.includes('Histórico escrito pela família'));
}

function testPromptOmitsEmptyHistory() {
  const prompt = buildAiNannyUserPrompt({
    question: 'Oi',
    contextBlock: 'ctx',
    familyHistoryBlock: '',
  });
  assert.ok(!prompt.includes('Histórico informado pela família'));
}

testFormatHistoryForPrompt();
testPromptIncludesHistory();
function testManualScenarioPrompt() {
  const history =
    'Minha bebê nasceu prematura de 34 semanas e tem refluxo.';
  const question =
    'Ela está chorando muito depois de mamar, o que pode ser?';
  const prompt = buildAiNannyUserPrompt({
    question,
    contextBlock: 'Nome: Bebê',
    familyHistoryBlock: formatHistoryForPrompt(history),
  });

  assert.ok(prompt.includes('34 semanas'));
  assert.ok(prompt.includes('refluxo'));
  assert.ok(prompt.includes('chorando muito depois de mamar'));
  assert.ok(prompt.length < 2000, 'prompt compacto para tokens');
}

function testTruncationSavesTokens() {
  const long = 'x'.repeat(2000);
  const out = formatHistoryForPrompt(long);
  assert.ok(out.length <= 752);
}

testPromptOmitsEmptyHistory();
testManualScenarioPrompt();
testTruncationSavesTokens();
console.log('aiProfile.test.js: OK');
