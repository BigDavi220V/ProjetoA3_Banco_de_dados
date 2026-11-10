/* =====================================================================
   03_drop_tables.sql  —  DDL: DROP TABLE IF EXISTS
   ---------------------------------------------------------------------
   Deixa os scripts "re-executáveis": antes de criar, apaga o que existir.
   A ORDEM IMPORTA: primeiro as tabelas FILHAS (que têm FK), depois as
   tabelas MÃES. Se apagar a mãe antes, o SQL Server recusa por causa
   da integridade referencial.
   Views, funções, procedures e triggers são recriadas com
   CREATE OR ALTER nos scripts da pasta 02_programabilidade.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

-- Views dependem das tabelas: removidas primeiro
DROP VIEW IF EXISTS relatorio.vw_atendimentos_especialidade_mes;
DROP VIEW IF EXISTS clinico.vw_linha_tempo_crianca;
DROP VIEW IF EXISTS atendimento.vw_agenda_detalhada;
DROP VIEW IF EXISTS clinico.vw_triagem_situacao;
DROP VIEW IF EXISTS cadastro.vw_crianca_resumo;
GO

-- 1) atendimento (filhas de tudo)
DROP TABLE IF EXISTS atendimento.consulta_sinal_alerta;
DROP TABLE IF EXISTS atendimento.vacina_aplicada;
DROP TABLE IF EXISTS atendimento.consulta;
DROP TABLE IF EXISTS atendimento.agendamento;

-- 2) segurança / auditoria
DROP TABLE IF EXISTS auditoria.log_auditoria;
DROP TABLE IF EXISTS seguranca.usuario;
DROP TABLE IF EXISTS seguranca.perfil;

-- 3) período neonatal
DROP TABLE IF EXISTS clinico.oximetria_afericao;
DROP TABLE IF EXISTS clinico.triagem_resultado_lado;
DROP TABLE IF EXISTS clinico.triagem_neonatal;
DROP TABLE IF EXISTS clinico.alta_maternidade;
DROP TABLE IF EXISTS clinico.internacao_setor;
DROP TABLE IF EXISTS clinico.internacao_neonatal;
DROP TABLE IF EXISTS clinico.nascimento;
DROP TABLE IF EXISTS clinico.prontuario;
DROP TABLE IF EXISTS cadastro.crianca;

-- 4) gestação e parto
DROP TABLE IF EXISTS clinico.parto;
DROP TABLE IF EXISTS clinico.vacina_prenatal;
DROP TABLE IF EXISTS clinico.sorologia_prenatal;
DROP TABLE IF EXISTS clinico.gestacao;

-- 5) cadastro base
DROP TABLE IF EXISTS cadastro.gestante_telefone;
DROP TABLE IF EXISTS cadastro.gestante;
DROP TABLE IF EXISTS cadastro.profissional_especialidade;
DROP TABLE IF EXISTS cadastro.profissional;
DROP TABLE IF EXISTS cadastro.unidade_saude;

-- 6) domínios (mães de todo mundo)
DROP TABLE IF EXISTS dominio.referencia_peso_ig;
DROP TABLE IF EXISTS dominio.setor_internacao;
DROP TABLE IF EXISTS dominio.sinal_alerta;
DROP TABLE IF EXISTS dominio.tipo_triagem;
DROP TABLE IF EXISTS dominio.vacina;
DROP TABLE IF EXISTS dominio.agravo;
DROP TABLE IF EXISTS dominio.categoria_profissional;
DROP TABLE IF EXISTS dominio.especialidade;
GO

DROP SEQUENCE IF EXISTS clinico.seq_prontuario;
GO
PRINT 'Tabelas antigas removidas (se existiam).';
GO
