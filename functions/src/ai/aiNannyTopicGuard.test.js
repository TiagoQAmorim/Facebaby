const assert = require('assert');
const {
  classifyAiNannyQuestion,
  offTopicRefusalMessage,
} = require('./aiNannyTopicGuard');

assert.strictEqual(classifyAiNannyQuestion('Quem ganhou a eleição?'), 'off_topic');
assert.strictEqual(classifyAiNannyQuestion('Melhor filme de 2024?'), 'off_topic');
assert.strictEqual(classifyAiNannyQuestion('O bebê não dorme à noite'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('Posso dar paracetamol infantil?'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('Estou grávida, o que posso comer?'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('Posso tomar remédio grávida?'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('grávida'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('Estou grávida'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('Posso fazer exercício grávida?'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('Como preparar o enxoval?'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('Dicas de educação para criança de 5 anos'), 'allowed');
assert.strictEqual(classifyAiNannyQuestion('Como ensinar limites na escola?'), 'allowed');
assert.strictEqual(
  classifyAiNannyQuestion('Filme calmo para ver com bebê de 3 meses'),
  'allowed',
);
assert.strictEqual(
  classifyAiNannyQuestion('Estou exausta e com culpa, preciso desabafar'),
  'allowed',
);
assert.strictEqual(
  classifyAiNannyQuestion('Meu marido não ajuda com o bebê'),
  'allowed',
);
assert.ok(offTopicRefusalMessage('pt').includes('FaceBaby'));

console.log('aiNannyTopicGuard.test.js: OK');
