// controllers/cadernetaController.js — seções da caderneta, consultas e vacinas
const cadernetaService = require('../services/cadernetaService');
const atendimentoService = require('../services/atendimentoService');

const h = fn => (req, res, next) => Promise.resolve(fn(req, res)).catch(next);

module.exports = {
  obter: h(async (req, res) => res.json(await cadernetaService.obter(req.params.id))),

  salvarPrenatal: h(async (req, res) => {
    await cadernetaService.salvarPrenatal(req.params.id, req.body, req.usuario);
    res.json({ mensagem: 'Pré-natal salvo.' });
  }),

  salvarNascimento: h(async (req, res) => {
    await cadernetaService.salvarNascimento(req.params.id, req.body, req.usuario);
    res.json({ mensagem: 'Parto e nascimento salvos.' });
  }),

  salvarAlta: h(async (req, res) => {
    await cadernetaService.salvarAlta(req.params.id, req.body, req.usuario);
    res.json({ mensagem: 'Internação e alta salvas.' });
  }),

  salvarTriagem: h(async (req, res) => {
    const r = await cadernetaService.salvarTriagem(req.params.id, req.params.codigo, req.body, req.usuario);
    res.json({ ...r, mensagem: 'Triagem salva.' });
  }),

  registrarConsulta: h(async (req, res) => {
    const id = await atendimentoService.registrarConsulta(req.params.id, req.body, req.usuario);
    res.status(201).json({ consulta_id: id, mensagem: 'Consulta registrada.' });
  }),

  registrarVacina: h(async (req, res) => {
    const id = await atendimentoService.registrarVacina(req.params.id, req.body, req.usuario);
    res.status(201).json({ vacina_aplicada_id: id, mensagem: 'Vacina registrada.' });
  }),

  excluirVacina: h(async (req, res) => {
    await atendimentoService.excluirVacina(req.params.id, req.usuario);
    res.json({ mensagem: 'Registro de vacina removido.' });
  }),
};
