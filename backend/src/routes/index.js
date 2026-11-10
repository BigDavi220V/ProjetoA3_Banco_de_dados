/**
 * routes/index.js — Mapa da API
 *
 * Fluxo de cada requisição (arquitetura em camadas):
 *   rota -> middleware (autenticar/exigir) -> controller -> service -> repository (SQL) -> SQL Server
 */
const express = require('express');
const { autenticar: auth, exigir } = require('../middlewares/auth');
const authCtrl = require('../controllers/authController');
const cad      = require('../controllers/cadastroController');
const cnt      = require('../controllers/cadernetaController');
const agd      = require('../controllers/agendaController');
const { getPool } = require('../config/db');

const router = express.Router();

// Saúde da API (verifica também a conexão com o banco)
router.get('/health', async (req, res) => {
  try {
    const pool = await getPool();
    const r = await pool.request().query('SELECT DB_NAME() AS banco, @@VERSION AS versao, SYSDATETIME() AS agora;');
    res.json({ ok: true, ...r.recordset[0] });
  } catch (err) {
    res.status(503).json({ ok: false, erro: err.message });
  }
});

// Autenticação
router.post('/auth/login', authCtrl.login);
router.get ('/auth/me', auth, authCtrl.eu);

// Apoio
router.get('/dominios',      auth, cad.dominios);
router.get('/dashboard',     auth, exigir('dashboard.ver'),     cad.dashboard);
router.get('/profissionais', auth, exigir('profissionais.ver'), cad.profissionais);
router.get('/gestantes',     auth, exigir('criancas.ver'),      cad.gestantes);

// Crianças (CRUD)
router.get   ('/criancas',              auth, exigir('criancas.ver'),     cad.listarCriancas);
router.get   ('/criancas/:id',          auth, exigir('criancas.ver'),     cad.obterCrianca);
router.post  ('/criancas',              auth, exigir('criancas.editar'),  cad.criarCrianca);
router.put   ('/criancas/:id',          auth, exigir('criancas.editar'),  cad.atualizarCrianca);
router.delete('/criancas/:id',          auth, exigir('criancas.editar', 'criancas.excluir'), cad.removerCrianca);
router.patch ('/criancas/:id/reativar', auth, exigir('criancas.editar'),  cad.reativarCrianca);

// Caderneta (prontuário) — leitura e seções dos formulários
router.get('/criancas/:id/caderneta',          auth, exigir('caderneta.ver'),    cnt.obter);
router.put('/criancas/:id/prenatal',           auth, exigir('caderneta.editar'), cnt.salvarPrenatal);
router.put('/criancas/:id/nascimento',         auth, exigir('caderneta.editar'), cnt.salvarNascimento);
router.put('/criancas/:id/alta',               auth, exigir('caderneta.editar'), cnt.salvarAlta);
router.put('/criancas/:id/triagens/:codigo',   auth, exigir('caderneta.editar'), cnt.salvarTriagem);
router.post('/criancas/:id/consultas',         auth, exigir('consulta.registrar'), cnt.registrarConsulta);
router.post('/criancas/:id/vacinas',           auth, exigir('vacina.registrar'),   cnt.registrarVacina);
router.delete('/vacinas-aplicadas/:id',        auth, exigir('vacina.registrar'),   cnt.excluirVacina);

// Agenda
router.get   ('/agendamentos',              auth, exigir('agenda.ver'),       agd.listar);
router.post  ('/agendamentos',              auth, exigir('agenda.gerenciar'), agd.agendar);
router.patch ('/agendamentos/:id/cancelar', auth, exigir('agenda.gerenciar', 'consulta.registrar'), agd.cancelar);
router.delete('/agendamentos/:id',          auth, exigir('agenda.excluir'),   agd.excluir);

// Gestão
router.get('/relatorios',         auth, exigir('relatorios.ver'), agd.relatorios);
router.get('/relatorios/:codigo', auth, exigir('relatorios.ver'), agd.executarRelatorio);
router.get('/auditoria',          auth, exigir('auditoria.ver'),  agd.auditoria);

module.exports = router;
