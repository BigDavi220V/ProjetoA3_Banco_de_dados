/**
 * services/atendimentoService.js — Agenda, consultas e vacinas
 */
const { transacao } = require('../config/db');
const agendaRepo   = require('../repositories/agendaRepository');
const consultaRepo = require('../repositories/consultaRepository');
const { obrigatorios, inteiroOuNulo, decimalOuNulo, boolOuNulo, idValido, ErroNegocio } = require('../utils/validacao');

/* ----------------------------- AGENDA ----------------------------- */
const listarAgenda = filtros => agendaRepo.listar(filtros);

async function agendar(d, usuario) {
  const dados = {
    crianca_id: inteiroOuNulo(d.crianca_id),
    profissional_id: inteiroOuNulo(d.profissional_id),
    especialidade_id: inteiroOuNulo(d.especialidade_id),
    unidade_id: inteiroOuNulo(d.unidade_id) || usuario.unidade_id,
    data_hora: d.data_hora || (d.data && d.hora ? `${d.data}T${d.hora}` : null),
    tipo_atendimento: d.tipo_atendimento,
    local_atendimento: d.local_atendimento || 'UNIDADE',
    duracao_min: inteiroOuNulo(d.duracao_min) || 30,
    observacao: d.observacao || null,
  };
  obrigatorios(dados, [['crianca_id', 'criança'], ['profissional_id', 'profissional'],
    ['especialidade_id', 'especialidade'], ['unidade_id', 'unidade'], ['data_hora', 'data e hora'],
    ['tipo_atendimento', 'tipo de atendimento']]);
  // As demais regras (conflito, prazo da 1ª semana...) estão na procedure do banco
  return transacao(usuario.usuario_id, tx => agendaRepo.agendar(dados, usuario.usuario_id, tx));
}

async function cancelar(id, { motivo, status }, usuario) {
  if (status !== 'FALTOU' && !(motivo && String(motivo).trim())) {
    throw new ErroNegocio('Informe o motivo do cancelamento.', 422);
  }
  await transacao(usuario.usuario_id, tx =>
    agendaRepo.cancelar(idValido(id), motivo ? String(motivo).trim() : 'Não compareceu', status || 'CANCELADO', tx));
}

async function excluirAgendamento(id, usuario) {
  const afetadas = await transacao(usuario.usuario_id, tx => agendaRepo.excluir(idValido(id), tx));
  if (!afetadas) throw new ErroNegocio('Só é possível excluir agendamentos cancelados ou com falta, e sem consulta.', 422);
}

/* ---------------------------- CONSULTA ---------------------------- */
async function registrarConsulta(criancaId, d, usuario) {
  if (!usuario.profissional_id) throw new ErroNegocio('Seu usuário não está ligado a um profissional de saúde.', 403);
  const dados = {
    crianca_id: idValido(criancaId),
    profissional_id: usuario.profissional_id,
    especialidade_id: inteiroOuNulo(d.especialidade_id),
    unidade_id: inteiroOuNulo(d.unidade_id) || usuario.unidade_id,
    tipo_atendimento: d.tipo_atendimento || 'PRIMEIRA_SEMANA',
    local_atendimento: d.local_atendimento || 'UNIDADE',
    data_consulta: d.data_consulta || null,
    agendamento_id: inteiroOuNulo(d.agendamento_id),
    peso_g: inteiroOuNulo(d.peso_g),
    comprimento_cm: decimalOuNulo(d.comprimento_cm),
    perimetro_cefalico_cm: decimalOuNulo(d.perimetro_cefalico_cm),
    aleitamento: d.aleitamento || null,
    aleitamento_observacao: d.aleitamento_observacao || null,
    dificuldade_amamentar: boolOuNulo(d.dificuldade_amamentar),
    dificuldade_descricao: d.dificuldade_descricao || null,
    parou_amamentar: boolOuNulo(d.parou_amamentar),
    idade_desmame: d.idade_desmame || null,
    motivo_desmame: d.motivo_desmame || null,
    outros_sinais: d.outros_sinais || null,
    desenvolvimento_afeto: d.desenvolvimento_afeto || null,
    conduta: d.conduta || null,
    sinais: (d.sinais || []).map(s => ({ sinal_alerta_id: Number(s.sinal_alerta_id), presente: boolOuNulo(s.presente) === true })),
  };
  obrigatorios(dados, [['especialidade_id', 'especialidade'], ['unidade_id', 'unidade']]);
  if (dados.tipo_atendimento === 'PRIMEIRA_SEMANA') {
    obrigatorios(dados, [['peso_g', 'peso'], ['comprimento_cm', 'comprimento'], ['perimetro_cefalico_cm', 'perímetro cefálico (PC)']]);
  }
  return transacao(usuario.usuario_id, tx => consultaRepo.registrar(dados, tx));
}

/* ----------------------------- VACINA ----------------------------- */
async function registrarVacina(criancaId, d, usuario) {
  const dados = {
    crianca_id: idValido(criancaId),
    vacina_id: inteiroOuNulo(d.vacina_id),
    dose: d.dose,
    data_aplicacao: d.data_aplicacao,
    lote: d.lote ? String(d.lote).trim().toUpperCase() : null,
    profissional_id: usuario.profissional_id || null,
    unidade_id: inteiroOuNulo(d.unidade_id) || usuario.unidade_id,
  };
  obrigatorios(dados, [['vacina_id', 'vacina'], ['dose', 'dose'], ['data_aplicacao', 'data da aplicação'], ['unidade_id', 'unidade']]);
  return transacao(usuario.usuario_id, tx => consultaRepo.registrarVacina(dados, tx));
}

async function excluirVacina(id, usuario) {
  const afetadas = await transacao(usuario.usuario_id, tx => consultaRepo.excluirVacina(idValido(id), tx));
  if (!afetadas) throw new ErroNegocio('Registro de vacina não encontrado.', 404);
}

module.exports = {
  listarAgenda, agendar, cancelar, excluirAgendamento,
  registrarConsulta, registrarVacina, excluirVacina,
};
