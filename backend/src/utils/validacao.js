/**
 * utils/validacao.js — Pequenas validações reaproveitadas pelos services.
 * A validação "de verdade" também existe no banco (CHECK, FK, NOT NULL);
 * aqui ela serve para dar a mensagem certa ANTES de ir ao banco.
 */
const { ErroNegocio } = require('../middlewares/errorHandler');

function obrigatorios(obj, campos) {
  const faltando = campos.filter(([chave]) => obj[chave] === undefined || obj[chave] === null || obj[chave] === '');
  if (faltando.length) {
    throw new ErroNegocio(`Preencha: ${faltando.map(([, rotulo]) => rotulo).join(', ')}.`, 422);
  }
}

const soDigitos = v => (v === undefined || v === null ? null : String(v).replace(/\D/g, '') || null);

function inteiroOuNulo(v) {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n) : null;
}

function decimalOuNulo(v) {
  if (v === undefined || v === null || v === '') return null;
  const n = Number(String(v).replace(',', '.'));
  return Number.isFinite(n) ? n : null;
}

function boolOuNulo(v) {
  if (v === undefined || v === null || v === '') return null;
  if (v === true || v === 'true' || v === 1 || v === '1' || v === 'S') return true;
  if (v === false || v === 'false' || v === 0 || v === '0' || v === 'N') return false;
  return null;
}

function idValido(v) {
  const n = parseInt(v, 10);
  if (!Number.isInteger(n) || n <= 0) throw new ErroNegocio('Identificador inválido.', 400);
  return n;
}

module.exports = { obrigatorios, soDigitos, inteiroOuNulo, decimalOuNulo, boolOuNulo, idValido, ErroNegocio };
