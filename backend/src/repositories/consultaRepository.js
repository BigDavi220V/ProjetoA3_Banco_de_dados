/**
 * repositories/consultaRepository.js — Consultas e vacinas aplicadas
 */
const { query } = require('../config/db');

/** Chama a procedure que grava a consulta + sinais de alerta numa transação */
async function registrar(c, tx) {
  const [linha] = await query(`
    DECLARE @nova INT;
    EXEC atendimento.sp_registrar_consulta
         @crianca_id             = @crianca_id,
         @profissional_id        = @profissional_id,
         @especialidade_id       = @especialidade_id,
         @unidade_id             = @unidade_id,
         @tipo_atendimento       = @tipo_atendimento,
         @local_atendimento      = @local_atendimento,
         @data_consulta          = @data_consulta,
         @agendamento_id         = @agendamento_id,
         @peso_g                 = @peso_g,
         @comprimento_cm         = @comprimento_cm,
         @perimetro_cefalico_cm  = @perimetro_cefalico_cm,
         @aleitamento            = @aleitamento,
         @aleitamento_observacao = @aleitamento_observacao,
         @dificuldade_amamentar  = @dificuldade_amamentar,
         @dificuldade_descricao  = @dificuldade_descricao,
         @parou_amamentar        = @parou_amamentar,
         @idade_desmame          = @idade_desmame,
         @motivo_desmame         = @motivo_desmame,
         @outros_sinais          = @outros_sinais,
         @desenvolvimento_afeto  = @desenvolvimento_afeto,
         @conduta                = @conduta,
         @sinais_json            = @sinais_json,
         @consulta_id            = @nova OUTPUT;
    SELECT @nova AS consulta_id;`,
  {
    crianca_id: c.crianca_id, profissional_id: c.profissional_id,
    especialidade_id: c.especialidade_id, unidade_id: c.unidade_id,
    tipo_atendimento: c.tipo_atendimento, local_atendimento: c.local_atendimento || 'UNIDADE',
    data_consulta: c.data_consulta || null, agendamento_id: c.agendamento_id || null,
    peso_g: c.peso_g, comprimento_cm: c.comprimento_cm, perimetro_cefalico_cm: c.perimetro_cefalico_cm,
    aleitamento: c.aleitamento, aleitamento_observacao: c.aleitamento_observacao,
    dificuldade_amamentar: c.dificuldade_amamentar,
    dificuldade_descricao: c.dificuldade_amamentar ? c.dificuldade_descricao : null,
    parou_amamentar: c.parou_amamentar,
    idade_desmame: c.parou_amamentar ? c.idade_desmame : null,
    motivo_desmame: c.parou_amamentar ? c.motivo_desmame : null,
    outros_sinais: c.outros_sinais, desenvolvimento_afeto: c.desenvolvimento_afeto,
    conduta: c.conduta,
    sinais_json: JSON.stringify(c.sinais || []),
  }, tx);
  return linha.consulta_id;
}

async function registrarVacina(v, tx) {
  const [linha] = await query(`
    INSERT INTO atendimento.vacina_aplicada
        (crianca_id, vacina_id, dose, data_aplicacao, lote, profissional_id, unidade_id, consulta_id)
    VALUES (@crianca_id, @vacina_id, @dose, @data_aplicacao, @lote, @profissional_id, @unidade_id, @consulta_id);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS vacina_aplicada_id;`,
  {
    crianca_id: v.crianca_id, vacina_id: v.vacina_id, dose: v.dose, data_aplicacao: v.data_aplicacao,
    lote: v.lote, profissional_id: v.profissional_id, unidade_id: v.unidade_id, consulta_id: v.consulta_id || null,
  }, tx);
  return linha.vacina_aplicada_id;
}

async function excluirVacina(id, tx) {
  const [linha] = await query(`
    DECLARE @apagadas TABLE (id INT);
    DELETE FROM atendimento.vacina_aplicada OUTPUT DELETED.vacina_aplicada_id INTO @apagadas
     WHERE vacina_aplicada_id = @id;
    SELECT COUNT(*) AS afetadas FROM @apagadas;`, { id }, tx);
  return linha.afetadas;
}

module.exports = { registrar, registrarVacina, excluirVacina };
