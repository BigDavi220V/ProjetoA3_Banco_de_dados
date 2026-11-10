/**
 * app.js — Servidor da Caderneta Digital da Criança
 *
 * ARQUITETURA (mesma organização em camadas do PEC APS):
 *   frontend/            HTML + CSS + JavaScript puro (servido por este Express)
 *   src/routes/          mapa de URLs da API
 *   src/middlewares/     autenticação, permissões e tradução de erros do banco
 *   src/controllers/     recebe HTTP, devolve JSON
 *   src/services/        regras de negócio e transações
 *   src/repositories/    TODO o SQL da aplicação (T-SQL parametrizado)
 *   src/config/          conexão com o SQL Server e matriz de permissões
 *
 * Banco: Microsoft SQL Server (CadernetaDigital) — scripts em /database
 */
require('dotenv').config();

const path      = require('path');
const express   = require('express');
const cors      = require('cors');
const rateLimit = require('express-rate-limit');
const routes    = require('./routes');
const { errorHandler } = require('./middlewares/errorHandler');
const { getPool } = require('./config/db');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(cors({ origin: (process.env.CORS_ORIGINS || `http://localhost:${PORT}`).split(',') }));
app.use(express.json({ limit: '1mb' }));

// Limite de tentativas de login (força bruta)
app.use('/api/auth/login', rateLimit({ windowMs: 15 * 60 * 1000, max: 30,
  message: { erro: 'Muitas tentativas de login. Aguarde alguns minutos.' } }));

// Frontend estático
const frontend = path.join(__dirname, '..', '..', 'frontend');
app.use(express.static(frontend));
app.get('/', (req, res) => res.redirect('/pages/login.html'));

// API
app.use('/api', routes);
app.use('/api', (req, res) => res.status(404).json({ erro: 'Rota não encontrada.' }));

app.use(errorHandler);

if (require.main === module) {
  app.listen(PORT, async () => {
    console.log('\n==============================================');
    console.log(' Caderneta Digital da Criança — A3 Banco de Dados');
    console.log(` http://localhost:${PORT}`);
    console.log('==============================================');
    try {
      await getPool();
    } catch (err) {
      console.error(`[DB] Não conectou ao SQL Server: ${err.message}`);
      console.error('[DB] Confira se a VM está ligada e os dados DB_* do arquivo .env.');
    }
  });
}

module.exports = app;
