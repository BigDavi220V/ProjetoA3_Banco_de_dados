/**
 * config/db.js — Conexão com o Microsoft SQL Server (driver "mssql")
 *
 * Toda conversa com o banco passa por aqui. As camadas acima
 * (repositories) só escrevem o SQL; este arquivo cuida de:
 *   - pool de conexões (reaproveita conexões abertas)
 *   - parâmetros (@nome) -> evita SQL Injection
 *   - transações + SESSION_CONTEXT (quem é o usuário, para a auditoria)
 *   - converter DATE/DATETIME2/TIME do banco em texto simples para o JSON
 */
const sql = require('mssql');
require('dotenv').config();

const config = {
  server:   process.env.DB_SERVER || 'localhost',
  port:     parseInt(process.env.DB_PORT, 10) || 1433,
  database: process.env.DB_NAME || 'CadernetaDigital',
  user:     process.env.DB_USER || 'app_caderneta',
  password: process.env.DB_PASSWORD || '',
  options: {
    encrypt: process.env.DB_ENCRYPT === 'true',
    trustServerCertificate: true,   // VM local com certificado autoassinado
    useUTC: false,                  // datas no fuso do servidor (Bahia), sem conversão
    enableArithAbort: true,
  },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
  connectionTimeout: 15000,
  requestTimeout: 30000,
};

let poolPromise = null;

/** Abre (uma vez) e devolve o pool de conexões */
function getPool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(config)
      .connect()
      .then(pool => {
        console.log(`[DB] Conectado ao SQL Server ${config.server}:${config.port} / ${config.database}`);
        return pool;
      })
      .catch(err => {
        poolPromise = null; // permite tentar de novo na próxima requisição
        throw err;
      });
  }
  return poolPromise;
}

/* ------------------------------------------------------------------ */
/* Conversão de datas para texto (evita o "deslocamento de fuso" do JSON) */
const pad = n => String(n).padStart(2, '0');
const fmtData = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const fmtHora = d => `${pad(d.getHours())}:${pad(d.getMinutes())}`;
const fmtDataHora = d => `${fmtData(d)}T${fmtHora(d)}:${pad(d.getSeconds())}`;

function normalizar(recordset) {
  if (!recordset) return [];
  const colunas = recordset.columns || {};
  const tipos = {};
  for (const [nome, meta] of Object.entries(colunas)) {
    const t = meta.type;
    tipos[nome] = t === sql.Date ? 'date' : t === sql.Time ? 'time'
      : (t === sql.DateTime2 || t === sql.DateTime || t === sql.SmallDateTime || t === sql.DateTimeOffset) ? 'datetime'
      : null;
  }
  return recordset.map(linha => {
    for (const k of Object.keys(linha)) {
      const v = linha[k];
      if (v instanceof Date) {
        linha[k] = tipos[k] === 'date' ? fmtData(v) : tipos[k] === 'time' ? fmtHora(v) : fmtDataHora(v);
      }
    }
    return linha;
  });
}

/* ------------------------------------------------------------------ */
/**
 * Liga os parâmetros ao request.
 * Aceita valor simples ({ nome: 'Ana' }) — o driver deduz o tipo —
 * ou explícito ({ peso: { type: sql.SmallInt, value: 3200 } }).
 */
function bind(request, params = {}) {
  for (const [nome, valor] of Object.entries(params)) {
    if (valor && typeof valor === 'object' && 'type' in valor) {
      request.input(nome, valor.type, valor.value === undefined ? null : valor.value);
    } else {
      request.input(nome, valor === undefined || valor === '' ? null : valor);
    }
  }
  return request;
}

/**
 * Executa um comando SQL parametrizado e devolve as linhas.
 * @param {string} texto   SQL com parâmetros @nome
 * @param {object} params  valores dos parâmetros
 * @param {sql.Transaction} [tx] transação em andamento (opcional)
 */
async function query(texto, params = {}, tx = null) {
  const request = tx ? new sql.Request(tx) : new sql.Request(await getPool());
  bind(request, params);
  const resultado = await request.query(texto);
  return normalizar(resultado.recordset);
}

/** Igual a query(), mas devolve todos os result sets (SQL com vários SELECTs) */
async function queryMultiplo(texto, params = {}, tx = null) {
  const request = tx ? new sql.Request(tx) : new sql.Request(await getPool());
  bind(request, params);
  const resultado = await request.query(texto);
  return (resultado.recordsets || []).map(normalizar);
}

/**
 * Abre uma transação, informa ao banco QUEM está gravando
 * (sp_set_session_context -> lido pelos triggers de auditoria),
 * executa o trabalho e faz COMMIT. Qualquer erro -> ROLLBACK.
 */
async function transacao(usuarioId, trabalho) {
  const pool = await getPool();
  const tx = new sql.Transaction(pool);
  await tx.begin();
  try {
    await query('EXEC sp_set_session_context @key = N\'usuario_id\', @value = @uid;', { uid: usuarioId || null }, tx);
    const retorno = await trabalho(tx);
    await tx.commit();
    return retorno;
  } catch (err) {
    try { await tx.rollback(); } catch (_) { /* já desfeita pelo XACT_ABORT */ }
    throw err;
  }
}

module.exports = { sql, getPool, query, queryMultiplo, transacao, config };
