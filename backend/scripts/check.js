/**
 * scripts/check.js — Verificação rápida SEM banco: carrega todos os módulos
 * e lista as rotas da API. Útil para conferir se o código não tem erro de
 * sintaxe antes de ligar a VM.   Uso: npm run check
 */
const app = require('../src/app');
const rotas = [];
const pilha = app._router.stack.find(l => l.name === 'router' && l.regexp.test('/api')).handle.stack;
for (const camada of pilha) {
  if (!camada.route) continue;
  for (const metodo of Object.keys(camada.route.methods)) rotas.push(`${metodo.toUpperCase().padEnd(6)} /api${camada.route.path}`);
}
console.log(`✔ Módulos carregados. ${rotas.length} rotas:\n  ${rotas.join('\n  ')}`);
process.exit(0);
