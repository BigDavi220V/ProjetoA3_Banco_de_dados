// controllers/agendaController.js — agenda e relatórios
const atendimentoService = require('../services/atendimentoService');
const relatorioRepo = require('../repositories/relatorioRepository');
const { ErroNegocio } = require('../utils/validacao');

const h = fn => (req, res, next) => Promise.resolve(fn(req, res)).catch(next);

const hoje = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

module.exports = {
  listar: h(async (req, res) => res.json(await atendimentoService.listarAgenda({
    data: req.query.data || (req.query.crianca_id ? null : hoje()),
    dataFim: req.query.data_fim,
    unidadeId: req.query.unidade_id,
    profissionalId: req.query.profissional_id,
    criancaId: req.query.crianca_id,
    status: req.query.status,
  }))),

  agendar: h(async (req, res) => {
    const id = await atendimentoService.agendar(req.body, req.usuario);
    res.status(201).json({ agendamento_id: id, mensagem: 'Agendamento confirmado.' });
  }),

  cancelar: h(async (req, res) => {
    await atendimentoService.cancelar(req.params.id, req.body || {}, req.usuario);
    res.json({ mensagem: req.body?.status === 'FALTOU' ? 'Falta registrada.' : 'Agendamento cancelado.' });
  }),

  excluir: h(async (req, res) => {
    await atendimentoService.excluirAgendamento(req.params.id, req.usuario);
    res.json({ mensagem: 'Agendamento excluído definitivamente.' });
  }),

  relatorios: h(async (req, res) => res.json(relatorioRepo.catalogo())),

  executarRelatorio: h(async (req, res) => {
    const fim = req.query.fim || hoje();
    const inicio = req.query.inicio || (() => {
      const d = new Date(); d.setDate(d.getDate() - 90);
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    })();
    if (inicio > fim) throw new ErroNegocio('A data inicial deve ser antes da final.', 422);
    const r = await relatorioRepo.executar(req.params.codigo, { inicio, fim });
    if (!r) throw new ErroNegocio('Relatório não encontrado.', 404);
    res.json({ ...r, inicio, fim });
  }),

  auditoria: h(async (req, res) => res.json(await relatorioRepo.auditoria({
    tabela: req.query.tabela, limite: req.query.limite,
  }))),
};
