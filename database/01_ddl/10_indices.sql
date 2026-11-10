/* =====================================================================
   10_indices.sql  —  DDL: índices de busca
   ---------------------------------------------------------------------
   PK e UNIQUE já criam índice sozinhos. Aqui ficam os índices para:
   (a) colunas de FK usadas em JOIN (o SQL Server NÃO cria sozinho);
   (b) filtros frequentes das telas (nome, data da agenda, período).
   INCLUDE = colunas extras guardadas no índice para a consulta não
   precisar voltar na tabela ("índice de cobertura").
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

-- Busca por nome na recepção (tela Crianças e Gestantes)
CREATE INDEX ix_crianca_nome   ON cadastro.crianca  (nome) INCLUDE (data_nascimento, ativo);
CREATE INDEX ix_gestante_nome  ON cadastro.gestante (nome) INCLUDE (data_nascimento);

-- FKs usadas nos JOINs
CREATE INDEX ix_crianca_gestacao       ON cadastro.crianca (gestacao_id);
CREATE INDEX ix_crianca_unidade        ON cadastro.crianca (unidade_referencia_id) WHERE ativo = 1;
CREATE INDEX ix_gestacao_gestante      ON clinico.gestacao (gestante_id);
CREATE INDEX ix_profissional_categoria ON cadastro.profissional (categoria_id);
CREATE INDEX ix_profissional_unidade   ON cadastro.profissional (unidade_id);
CREATE INDEX ix_profesp_especialidade  ON cadastro.profissional_especialidade (especialidade_id);
CREATE INDEX ix_triagem_tipo           ON clinico.triagem_neonatal (tipo_triagem_id);
CREATE INDEX ix_vacapl_crianca         ON atendimento.vacina_aplicada (crianca_id, data_aplicacao);

-- Agenda do dia (filtro por data e profissional)
CREATE INDEX ix_agendamento_data       ON atendimento.agendamento (data_hora, status)
    INCLUDE (crianca_id, profissional_id, especialidade_id, tipo_atendimento);
CREATE INDEX ix_agendamento_crianca    ON atendimento.agendamento (crianca_id);

-- Relatórios por período e especialidade
CREATE INDEX ix_consulta_data_especialidade ON atendimento.consulta (data_consulta, especialidade_id)
    INCLUDE (crianca_id, profissional_id, tipo_atendimento);
CREATE INDEX ix_consulta_crianca       ON atendimento.consulta (crianca_id, data_consulta DESC);

-- Auditoria: consultar o histórico de um registro
CREATE INDEX ix_log_tabela_chave       ON auditoria.log_auditoria (tabela, chave, data_hora DESC);
GO
PRINT 'Índices criados.';
GO
