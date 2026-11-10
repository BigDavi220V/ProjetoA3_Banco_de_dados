// controllers/cadastroController.js — crianças, gestantes, profissionais, domínios
const criancaService = require('../services/criancaService');
const dominioRepo = require('../repositories/dominioRepository');
const profissionalRepo = require('../repositories/profissionalRepository');
const dashboardRepo = require('../repositories/dashboardRepository');

// Envolve o handler: qualquer erro vai para o errorHandler
const h = fn => (req, res, next) => Promise.resolve(fn(req, res)).catch(next);

module.exports = {
  dominios: h(async (req, res) => res.json(await dominioRepo.listarTudo())),

  dashboard: h(async (req, res) => {
    // Gestor vê a rede toda; os demais, a própria unidade (pode trocar por ?unidade_id=)
    const unidade = req.query.unidade_id !== undefined
      ? (req.query.unidade_id || null)
      : (req.usuario.perfil === 'GESTOR' ? null : req.usuario.unidade_id);
    res.json(await dashboardRepo.resumo(unidade));
  }),

  profissionais: h(async (req, res) => res.json(await profissionalRepo.listar({
    especialidadeId: req.query.especialidade_id,
    categoriaId: req.query.categoria_id,
    unidadeId: req.query.unidade_id,
    busca: req.query.busca,
  }))),

  gestantes: h(async (req, res) => res.json(await criancaService.buscarGestantes(req.query.busca))),

  listarCriancas: h(async (req, res) => res.json(await criancaService.listar({
    busca: req.query.busca,
    situacao: ['ativas', 'inativas', 'todas'].includes(req.query.situacao) ? req.query.situacao : 'ativas',
    cuidado: req.query.cuidado,
    unidadeId: req.query.unidade_id,
  }))),

  obterCrianca: h(async (req, res) => res.json(await criancaService.obter(req.params.id))),

  criarCrianca: h(async (req, res) => {
    const id = await criancaService.criar(req.body, req.usuario);
    res.status(201).json({ crianca_id: id, mensagem: 'Criança cadastrada. Prontuário aberto.' });
  }),

  atualizarCrianca: h(async (req, res) => {
    await criancaService.atualizar(req.params.id, req.body, req.usuario);
    res.json({ mensagem: 'Cadastro atualizado.' });
  }),

  removerCrianca: h(async (req, res) => {
    const r = await criancaService.remover(req.params.id,
      { motivo: req.body?.motivo || req.query.motivo, fisico: req.query.fisico === '1' }, req.usuario);
    res.json({ ...r, mensagem: r.excluido ? 'Cadastro excluído definitivamente.' : 'Cadastro inativado.' });
  }),

  reativarCrianca: h(async (req, res) => {
    await criancaService.reativar(req.params.id, req.usuario);
    res.json({ mensagem: 'Cadastro reativado.' });
  }),
};
