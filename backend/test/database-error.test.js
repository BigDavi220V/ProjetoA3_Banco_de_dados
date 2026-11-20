const { test } = require('node:test');
const assert = require('node:assert/strict');
const { errorHandler } = require('../src/middlewares/errorHandler');

test('erro de conexão SQL Server serve para instalação local ou remota', () => {
  let status, body;
  const response = { status(value) { status = value; return this; }, json(value) { body = value; } };
  errorHandler({ code: 'ESOCKET', message: 'indisponível' }, {}, response, () => {});
  assert.equal(status, 503);
  assert.match(body.erro, /SQL Server/);
  assert.doesNotMatch(body.erro, /VM/);
});
