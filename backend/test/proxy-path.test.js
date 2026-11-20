const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const script = fs.readFileSync(path.join(__dirname, '../../frontend/assets/js/app.js'), 'utf8');

for (const prefix of ['', '/proxy/3001']) {
  test(`login usa o caminho da aplicação (${prefix || 'direto'})`, async () => {
    let requested;
    const location = { href: `http://localhost:8081${prefix}/pages/login.html` };
    const context = {
      URL, location, document: { baseURI: location.href, addEventListener() {} },
      window: { addEventListener() {} }, localStorage: { getItem() { return null; }, removeItem() {} },
      fetch: async url => { requested = url; return { ok: true, json: async () => ({}) }; },
    };
    vm.createContext(context);
    vm.runInContext(script, context);
    await vm.runInContext("api('/auth/login', { method: 'POST', body: {} })", context);
    assert.equal(requested, `${prefix}/api/auth/login`);
    vm.runInContext('Sessao.sair()', context);
    assert.equal(new URL(location.href, `http://localhost:8081${prefix}/pages/login.html`).pathname, `${prefix}/pages/login.html`);
  });
}
