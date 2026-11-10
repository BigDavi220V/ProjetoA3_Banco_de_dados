/**
 * repositories/dashboardRepository.js — Tela "Início"
 */
const { queryMultiplo } = require('../config/db');

async function resumo(unidadeId) {
  const [indicadores, agendaHoje, triagens, cuidado] = await queryMultiplo(`
    DECLARE @hoje DATE = CAST(GETDATE() AS DATE);

    SELECT
      (SELECT COUNT(*) FROM atendimento.agendamento
        WHERE CAST(data_hora AS DATE) = @hoje AND status = 'AGENDADO'
          AND (@unidade_id IS NULL OR unidade_id = @unidade_id))                    AS agendados_hoje,
      (SELECT COUNT(*) FROM atendimento.consulta
        WHERE CAST(data_consulta AS DATE) = @hoje
          AND (@unidade_id IS NULL OR unidade_id = @unidade_id))                    AS atendidos_hoje,
      (SELECT COUNT(*) FROM cadastro.crianca
        WHERE ativo = 1 AND DATEDIFF(DAY, data_nascimento, @hoje) <= 28
          AND (@unidade_id IS NULL OR unidade_referencia_id = @unidade_id))         AS recem_nascidos,
      (SELECT COUNT(*) FROM cadastro.vw_crianca_resumo
        WHERE ativo = 1 AND cuidado_especial = 1
          AND (@unidade_id IS NULL OR unidade_id = @unidade_id))                    AS cuidado_especial,
      (SELECT COUNT(*) FROM clinico.vw_triagem_situacao
        WHERE situacao IN ('PENDENTE','ATRASADA')
          AND (@unidade_id IS NULL OR unidade_id = @unidade_id))                    AS triagens_pendentes,
      (SELECT COUNT(*) FROM cadastro.crianca c
        WHERE c.ativo = 1 AND DATEDIFF(DAY, c.data_nascimento, @hoje) BETWEEN 3 AND 10
          AND (@unidade_id IS NULL OR c.unidade_referencia_id = @unidade_id)
          AND NOT EXISTS (SELECT 1 FROM atendimento.consulta co
                          WHERE co.crianca_id = c.crianca_id AND co.tipo_atendimento = 'PRIMEIRA_SEMANA')) AS sem_consulta_1a_semana;

    SELECT agendamento_id, data_hora, tipo_atendimento, local_atendimento, status, crianca_id,
           crianca_nome, idade_dias_no_dia, profissional_nome, especialidade_nome, unidade_nome, observacao
    FROM atendimento.vw_agenda_detalhada
    WHERE data = @hoje AND (@unidade_id IS NULL OR unidade_id = @unidade_id)
    ORDER BY data_hora;

    SELECT TOP (10) crianca_id, crianca_nome, nome_popular, situacao, resultado,
           DATEDIFF(DAY, data_nascimento, @hoje) AS dias_de_vida
    FROM clinico.vw_triagem_situacao
    WHERE (situacao IN ('PENDENTE','ATRASADA') OR resultado IN ('ALTERADO','REPETIR'))
      AND (@unidade_id IS NULL OR unidade_id = @unidade_id)
    ORDER BY CASE WHEN resultado IN ('ALTERADO','REPETIR') THEN 0
                  WHEN situacao = 'ATRASADA' THEN 1 ELSE 2 END, data_nascimento;

    SELECT TOP (10) crianca_id, nome, idade_dias, peso_nascer_g, ig_semanas, apgar_5min,
           alerta_baixo_peso, alerta_prematuro, alerta_apgar_baixo, alerta_mae_adolescente, alerta_utin
    FROM cadastro.vw_crianca_resumo
    WHERE ativo = 1 AND cuidado_especial = 1
      AND (@unidade_id IS NULL OR unidade_id = @unidade_id)
    ORDER BY idade_dias;`, { unidade_id: unidadeId || null });

  return { indicadores: indicadores[0], agendaHoje, triagens, cuidado };
}

module.exports = { resumo };
