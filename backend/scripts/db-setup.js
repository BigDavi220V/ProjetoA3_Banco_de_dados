/**
 * scripts/db-setup.js — Executa os scripts .sql da pasta /database
 *
 * Uso (na pasta backend):
 *   npm run db:setup      -> 01_ddl, 02_programabilidade, 03_dml, 05_dcl
 *   npm run db:reset      -> apaga o banco (00_reset) e faz o setup completo
 *   npm run db:consultas  -> roda as consultas DQL (04_dql) e mostra quantas linhas cada uma trouxe
 *
 * Conecta com o usuário ADMINISTRADOR (DB_ADMIN_USER, ex.: sa), porque
 * criar banco e logins exige privilégio alto. A aplicação, depois, usa o
 * usuário restrito app_caderneta (DB_USER).
 *
 * Os scripts usam "GO" (separador de lotes do SSMS/sqlcmd). O GO não é
 * SQL: o script divide o arquivo nele e envia lote por lote, sempre na
 * MESMA conexão (para o "USE CadernetaDigital" continuar valendo).
 */
const fs   = require('fs');
const path = require('path');
const sql  = require('mssql');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const PASTA = path.join(__dirname, '..', '..', 'database');
const args  = process.argv.slice(2);

const pastas = args.includes('--dql')
  ? ['04_dql']
  : [...(args.includes('--reset') ? ['00_reset'] : []), '01_ddl', '02_programabilidade', '03_dml', '05_dcl'];

const config = {
  server:   process.env.DB_SERVER || 'localhost',
  port:     parseInt(process.env.DB_PORT, 10) || 1433,
  database: 'master',
  user:     process.env.DB_ADMIN_USER || 'sa',
  password: process.env.DB_ADMIN_PASSWORD || '',
  options:  { encrypt: process.env.DB_ENCRYPT === 'true', trustServerCertificate: true, useUTC: false },
  pool:     { max: 1, min: 1 },          // UMA conexão só: o USE vale para todos os lotes
  requestTimeout: 120000,
};

function lotes(texto) {
  return texto
    .split(/^\s*GO\s*;?\s*$/gim)
    .map(l => l.trim())
    .filter(l => l && !/^(\/\*[\s\S]*?\*\/|--[^\n]*|\s)*$/.test(l)); // ignora lotes só de comentário
}

async function main() {
  const pool = await new sql.ConnectionPool(config).connect();
  console.log(`Conectado em ${config.server}:${config.port} como ${config.user}\n`);

  for (const pasta of pastas) {
    const dir = path.join(PASTA, pasta);
    const arquivos = fs.readdirSync(dir).filter(f => f.endsWith('.sql')).sort();
    for (const arquivo of arquivos) {
      const conteudo = fs.readFileSync(path.join(dir, arquivo), 'utf8');
      process.stdout.write(`▶ ${pasta}/${arquivo}\n`);
      for (const lote of lotes(conteudo)) {
        const req = new sql.Request(pool);
        req.on('info', info => console.log(`   ${info.message}`));
        try {
          const r = await req.batch(lote);
          if (pasta === '04_dql' && r.recordsets) {
            r.recordsets.forEach(rs => console.log(`   → ${rs.length} linha(s)`));
          }
        } catch (err) {
          console.error(`\n✖ Erro em ${pasta}/${arquivo}:\n   ${err.message}\n\nLote:\n${lote.slice(0, 800)}\n`);
          await pool.close();
          process.exit(1);
        }
      }
    }
  }
  await pool.close();
  console.log('\n✔ Concluído.');
}

main().catch(err => {
  console.error('Falha ao conectar:', err.message);
  console.error('Confira DB_SERVER, DB_PORT, DB_ADMIN_USER e DB_ADMIN_PASSWORD no backend/.env');
  process.exit(1);
});
