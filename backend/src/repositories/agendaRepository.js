/**
 * repositories/agendaRepository.js — Agenda
 * As regras de agendamento (conflito de horário, especialidade do
 * profissional, prazo da 1ª semana) ficam na PROCEDURE do banco;
 * aqui só chamamos com EXEC e lemos o parâmetro OUTPUT.
 */
const { query } = require('../config/db');

async function listar({ data, dataFim, unidadeId, profissionalId, criancaId, status } = {}) {
  return query(`
    SELECT agendamento_id, data_hora, data, duracao_min, tipo_atendimento, local_atendimento, status,
           motivo_cancelamento, observacao, crianca_id, crianca_nome, data_nascimento, idade_dias_no_dia,
           mae_nome, profissional_id, profissional_nome, categoria_nome, especialidade_id,
           especialidade_nome, unidade_id, unidade_nome, consulta_id
    FROM atendimento.vw_agenda_detalhada
    WHERE (@data IS NULL OR data >= @data)
      AND (@data_fim IS NULL OR data <= @data_fim)
      AND (@unidade_id      IS NULL OR unidade_id      = @unidade_id)
      AND (@profissional_id IS NULL OR profissional_id = @profissional_id)
      AND (@crianca_id      IS NULL OR crianca_id      = @crianca_id)
      AND (@status          IS NULL OR status          = @status)
    ORDER BY data_hora;`,
  {
    data: data || null,
    data_fim: dataFim || data || null,
    unidade_id: unidadeId || null,
    profissional_id: profissionalId || null,
    crianca_id: criancaId || null,
    status: status || null,
  });
}

async function agendar(a, usuarioId, tx) {
  const [linha] = await query(`
    DECLARE @novo INT;
    EXEC atendimento.sp_agendar_consulta
         @crianca_id        = @crianca_id,
         @profissional_id   = @profissional_id,
         @especialidade_id  = @especialidade_id,
         @unidade_id        = @unidade_id,
         @data_hora         = @data_hora,
         @tipo_atendimento  = @tipo_atendimento,
         @local_atendimento = @local_atendimento,
         @duracao_min       = @duracao_min,
         @observacao        = @observacao,
         @usuario_id        = @usuario_id,
         @agendamento_id    = @novo OUTPUT;
    SELECT @novo AS agendamento_id;`,
  {
    crianca_id: a.crianca_id, profissional_id: a.profissional_id,
    especialidade_id: a.especialidade_id, unidade_id: a.unidade_id,
    data_hora: a.data_hora, tipo_atendimento: a.tipo_atendimento,
    local_atendimento: a.local_atendimento || 'UNIDADE', duracao_min: a.duracao_min || 30,
    observacao: a.observacao, usuario_id: usuarioId,
  }, tx);
  return linha.agendamento_id;
}

async function cancelar(id, motivo, novoStatus, tx) {
  await query(`
    EXEC atendimento.sp_cancelar_agendamento
         @agendamento_id = @id, @motivo = @motivo, @novo_status = @novo_status;`,
  { id, motivo, novo_status: novoStatus || 'CANCELADO' }, tx);
}

/** Exclusão FÍSICA: só de agendamentos já encerrados e sem consulta */
async function excluir(id, tx) {
  const [linha] = await query(`
    DECLARE @apagados TABLE (agendamento_id INT);
    DELETE a
    OUTPUT DELETED.agendamento_id INTO @apagados
    FROM atendimento.agendamento a
    WHERE a.agendamento_id = @id
      AND a.status IN ('CANCELADO','FALTOU')
      AND NOT EXISTS (SELECT 1 FROM atendimento.consulta c WHERE c.agendamento_id = a.agendamento_id);
    SELECT COUNT(*) AS afetadas FROM @apagados;`, { id }, tx);
  return linha.afetadas;
}

module.exports = { listar, agendar, cancelar, excluir };
