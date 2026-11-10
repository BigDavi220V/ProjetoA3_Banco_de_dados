/* =====================================================================
   06_carga_agenda_consultas_vacinas.sql  —  DML: agenda, consultas da
   1ª semana / puericultura e vacinas aplicadas
   ---------------------------------------------------------------------
   Observe: os agendamentos 1 a 10 entram como AGENDADO. Quando as
   consultas são inseridas, o TRIGGER trg_consulta_conclui_agendamento
   muda o status deles para REALIZADO sozinho.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

DECLARE @hoje DATETIME2(0) = CAST(CAST(GETDATE() AS DATE) AS DATETIME2(0));
DECLARE @usuario_recepcao INT = (SELECT usuario_id FROM seguranca.usuario WHERE login = 'recepcao@caderneta.local');

SET IDENTITY_INSERT atendimento.agendamento ON;
INSERT INTO atendimento.agendamento
    (agendamento_id, crianca_id, profissional_id, especialidade_id, unidade_id, data_hora,
     tipo_atendimento, local_atendimento, status, motivo_cancelamento, observacao, criado_por_usuario_id)
VALUES
 -- passado (viram REALIZADO pelo trigger)
 ( 1,  2,  5, 5, 1, DATEADD(MINUTE,  9*60,    DATEADD(DAY, -2, @hoje)), 'PRIMEIRA_SEMANA', 'UNIDADE',  'AGENDADO', NULL, NULL, @usuario_recepcao),
 ( 2,  4,  5, 5, 1, DATEADD(MINUTE, 10*60,    DATEADD(DAY, -4, @hoje)), 'PRIMEIRA_SEMANA', 'UNIDADE',  'AGENDADO', NULL, N'Mãe adolescente: priorizar', @usuario_recepcao),
 ( 3,  5,  7, 5, 2, DATEADD(MINUTE,  9*60+30, DATEADD(DAY,-10, @hoje)), 'PRIMEIRA_SEMANA', 'UNIDADE',  'AGENDADO', NULL, NULL, @usuario_recepcao),
 ( 4,  6,  5, 5, 1, DATEADD(MINUTE, 14*60,    DATEADD(DAY,-15, @hoje)), 'PRIMEIRA_SEMANA', 'DOMICILIO','AGENDADO', NULL, N'Visita domiciliar', @usuario_recepcao),
 ( 5,  3, 11, 1, 2, DATEADD(MINUTE,  8*60+30, DATEADD(DAY, -5, @hoje)), 'PRIMEIRA_SEMANA', 'UNIDADE',  'AGENDADO', NULL, N'Egresso de UCIN', @usuario_recepcao),
 ( 6,  9,  7, 5, 2, DATEADD(MINUTE,  9*60,    DATEADD(DAY,-42, @hoje)), 'PRIMEIRA_SEMANA', 'UNIDADE',  'AGENDADO', NULL, NULL, @usuario_recepcao),
 ( 7,  9, 11, 1, 2, DATEADD(MINUTE, 10*60,    DATEADD(DAY,-15, @hoje)), 'PUERICULTURA',    'UNIDADE',  'AGENDADO', NULL, NULL, @usuario_recepcao),
 ( 8, 12,  7, 5, 2, DATEADD(MINUTE,  9*60,    DATEADD(DAY,-56, @hoje)), 'PRIMEIRA_SEMANA', 'UNIDADE',  'AGENDADO', NULL, NULL, @usuario_recepcao),
 ( 9, 12, 11, 1, 2, DATEADD(MINUTE, 11*60,    DATEADD(DAY,-30, @hoje)), 'PUERICULTURA',    'UNIDADE',  'AGENDADO', NULL, NULL, @usuario_recepcao),
 (10,  8, 11, 1, 2, DATEADD(MINUTE,  8*60,    DATEADD(DAY, -5, @hoje)), 'PUERICULTURA',    'UNIDADE',  'AGENDADO', NULL, N'Egressa de UTIN', @usuario_recepcao),
 -- passado sem consulta: falta e cancelamento
 (11,  6,  1, 1, 1, DATEADD(MINUTE,  9*60,    DATEADD(DAY, -1, @hoje)), 'PUERICULTURA',    'UNIDADE',  'FALTOU',    N'Não compareceu', NULL, @usuario_recepcao),
 (12, 12,  1, 1, 1, DATEADD(MINUTE, 15*60,    DATEADD(DAY, -3, @hoje)), 'PUERICULTURA',    'UNIDADE',  'CANCELADO', N'Família pediu remarcação', NULL, @usuario_recepcao),
 -- hoje
 (13,  1,  5, 5, 1, DATEADD(MINUTE,  8*60,    @hoje), 'PRIMEIRA_SEMANA',   'UNIDADE',   'AGENDADO', NULL, NULL, @usuario_recepcao),
 (14, 10,  5, 5, 1, DATEADD(MINUTE,  9*60,    @hoje), 'PRIMEIRA_SEMANA',   'UNIDADE',   'AGENDADO', NULL, N'Gemelar (1ª)', @usuario_recepcao),
 (15, 11,  5, 5, 1, DATEADD(MINUTE,  9*60+30, @hoje), 'PRIMEIRA_SEMANA',   'UNIDADE',   'AGENDADO', NULL, N'Gemelar (2ª)', @usuario_recepcao),
 (16, 13,  5, 8, 1, DATEADD(MINUTE, 14*60,    @hoje), 'VISITA_DOMICILIAR', 'DOMICILIO', 'AGENDADO', NULL, N'Parto domiciliar: fazer triagens pendentes', @usuario_recepcao),
 (17,  3, 11, 1, 2, DATEADD(MINUTE, 10*60,    @hoje), 'PUERICULTURA',      'UNIDADE',   'AGENDADO', NULL, N'Controle de peso', @usuario_recepcao),
 (18,  8,  4, 6, 5, DATEADD(MINUTE, 15*60,    @hoje), 'TRIAGEM',           'UNIDADE',   'AGENDADO', NULL, N'Rastreio de retinopatia da prematuridade', @usuario_recepcao),
 -- futuro
 (19,  7,  5, 5, 1, DATEADD(MINUTE,  8*60+30, DATEADD(DAY,  2, @hoje)), 'PRIMEIRA_SEMANA', 'UNIDADE', 'AGENDADO', NULL, NULL, @usuario_recepcao),
 (20,  4,  4, 6, 5, DATEADD(MINUTE, 10*60,    DATEADD(DAY,  3, @hoje)), 'TRIAGEM',         'UNIDADE', 'AGENDADO', NULL, N'Reflexo vermelho alterado OE', @usuario_recepcao),
 (21,  5, 10, 7, 3, DATEADD(MINUTE, 11*60,    DATEADD(DAY,  1, @hoje)), 'TRIAGEM',         'UNIDADE', 'AGENDADO', NULL, N'Reteste EOA', @usuario_recepcao),
 (22,  2,  1, 1, 1, DATEADD(MINUTE,  9*60,    DATEADD(DAY, 24, @hoje)), 'PUERICULTURA',    'UNIDADE', 'AGENDADO', NULL, N'Consulta de 1 mês', @usuario_recepcao),
 (23,  9, 11, 1, 2, DATEADD(MINUTE,  9*60,    DATEADD(DAY, 15, @hoje)), 'PUERICULTURA',    'UNIDADE', 'AGENDADO', NULL, N'Consulta de 2 meses', @usuario_recepcao),
 (24, 12,  8, 8, 2, DATEADD(MINUTE, 14*60,    DATEADD(DAY,  1, @hoje)), 'VACINA',          'UNIDADE', 'AGENDADO', NULL, N'Vacinas dos 2 meses', @usuario_recepcao);
SET IDENTITY_INSERT atendimento.agendamento OFF;
GO

/* ---------- CONSULTAS (ligadas aos agendamentos 1..10) ---------- */
SET IDENTITY_INSERT atendimento.consulta ON;
INSERT INTO atendimento.consulta
    (consulta_id, crianca_id, profissional_id, especialidade_id, unidade_id, agendamento_id,
     tipo_atendimento, local_atendimento, data_consulta,
     peso_g, comprimento_cm, perimetro_cefalico_cm,
     aleitamento, aleitamento_observacao, dificuldade_amamentar, dificuldade_descricao,
     parou_amamentar, desenvolvimento_afeto, outros_sinais, conduta)
SELECT v.consulta_id, a.crianca_id, a.profissional_id, a.especialidade_id, a.unidade_id, a.agendamento_id,
       a.tipo_atendimento, a.local_atendimento, DATEADD(MINUTE, 10, a.data_hora),
       v.peso, v.comp, v.pc, v.aleit, v.aleit_obs, v.dif, v.dif_desc, 0, v.afeto, v.outros, v.conduta
FROM (VALUES
 ( 1,  1, 3300, 50.0, 34.6, 'LME',   NULL, 0, NULL,
       N'Mãe atenta, conversa com o bebê durante a mamada; pai presente.', NULL,
       N'Orientada sobre coto umbilical e sinais de alerta. Retorno com 1 mês.'),
 ( 2,  2, 2350, 46.2, 32.3, 'LME',   NULL, 1, N'Pega incorreta e fissura mamilar',
       N'Mãe adolescente; avó materna é a principal rede de apoio.', N'Icterícia até zona 2',
       N'Correção da pega. Encaminhada à oftalmologia (reflexo vermelho alterado OE). Acompanhar VDRL.'),
 ( 3,  3, 4150, 53.2, 36.1, 'LM_LA', N'Complemento prescrito na maternidade', 0, NULL,
       N'Boa interação mãe-bebê.', NULL,
       N'Plano de retirada gradual do complemento.'),
 ( 4,  4, 3050, 48.8, 33.8, 'LME',   NULL, 0, NULL,
       N'Família organizada, irmão mais velho participa dos cuidados.', NULL,
       N'Visita domiciliar sem intercorrências.'),
 ( 5,  5, 2260, 45.3, 31.8, 'LME',   NULL, 1, N'Bebê sonolento nas mamadas (prematuro)',
       N'Mãe insegura, muito apoio do companheiro.', NULL,
       N'Pesar semanalmente. Retorno em 7 dias.'),
 ( 6,  6, 3450, 51.0, 35.1, 'LME',   NULL, 0, NULL,
       N'Vínculo adequado.', NULL,
       N'Mãe sem pré-natal: iniciar acompanhamento da família pela ESF.'),
 ( 7,  7, 4400, 55.0, 37.5, 'LME',   NULL, 0, NULL,
       N'Sorriso social presente.', NULL,
       N'Crescimento adequado.'),
 ( 8,  8, 3420, 50.2, 35.2, 'LME',   NULL, 0, NULL,
       N'Vínculo adequado.', NULL,
       N'Sem intercorrências.'),
 ( 9,  9, 4500, 54.5, 37.8, 'LM_LA', N'Mãe voltou ao trabalho em meio período', 0, NULL,
       N'Sorriso social presente; fixa o olhar.', NULL,
       N'Orientada sobre ordenha e armazenamento do leite.'),
 (10, 10, 2010, 43.0, 31.0, 'LM_LA', NULL, 0, NULL,
       N'Mãe participa do método canguru em casa.', NULL,
       N'Egressa de UTIN: manter seguimento. Oftalmologia agendada (ROP).')
) AS v (consulta_id, agendamento_id, peso, comp, pc, aleit, aleit_obs, dif, dif_desc, afeto, outros, conduta)
JOIN atendimento.agendamento a ON a.agendamento_id = v.agendamento_id;
SET IDENTITY_INSERT atendimento.consulta OFF;
GO

/* Sinais de alerta das consultas da 1ª semana: todos "Não", exceto
   icterícia na consulta 2 (CROSS JOIN gera as 8 perguntas por consulta) */
INSERT INTO atendimento.consulta_sinal_alerta (consulta_id, sinal_alerta_id, presente)
SELECT co.consulta_id,
       s.sinal_alerta_id,
       CASE WHEN co.consulta_id = 2 AND s.nome = N'Icterícia' THEN 1 ELSE 0 END
FROM atendimento.consulta co
CROSS JOIN dominio.sinal_alerta s
WHERE co.tipo_atendimento = 'PRIMEIRA_SEMANA';
GO

/* ---------- VACINAS APLICADAS NA CRIANÇA ----------
   Hepatite B (dose ao nascer) na maternidade para todos que nasceram lá;
   BCG para quem atingiu 2.000 g; a criança 13 tomou Hepatite B na USF. */
INSERT INTO atendimento.vacina_aplicada (crianca_id, vacina_id, dose, data_aplicacao, lote, profissional_id, unidade_id)
SELECT c.crianca_id, vac.vacina_id, v.dose, DATEADD(DAY, v.dia_vida, c.data_nascimento), v.lote, v.profissional_id, v.unidade_id
FROM (VALUES
 ( 1, 'HEPB', 'D1', 0, 'HB24A118', 9, 3), ( 1, 'BCG', 'DU', 1, 'BCG2410', 9, 3),
 ( 2, 'HEPB', 'D1', 0, 'HB24A118', 9, 3), ( 2, 'BCG', 'DU', 1, 'BCG2410', 9, 3),
 ( 3, 'HEPB', 'D1', 0, 'HB24A118', 9, 5), ( 3, 'BCG', 'DU', 6, 'BCG2410', 9, 5),
 ( 4, 'HEPB', 'D1', 0, 'HB24A118', 9, 3), ( 4, 'BCG', 'DU', 2, 'BCG2410', 9, 3),
 ( 5, 'HEPB', 'D1', 0, 'HB24A118', 9, 3), ( 5, 'BCG', 'DU', 2, 'BCG2410', 9, 3),
 ( 6, 'HEPB', 'D1', 0, 'HB24A118', 6, 4), ( 6, 'BCG', 'DU', 3, 'BCG2410', 8, 1),
 ( 7, 'HEPB', 'D1', 0, 'HB24A207', 9, 3),
 ( 8, 'HEPB', 'D1', 0, 'HB24A118', 9, 5),
 ( 9, 'HEPB', 'D1', 0, 'HB24A118', 9, 3), ( 9, 'BCG', 'DU', 1, 'BCG2398', 9, 3),
 (10, 'HEPB', 'D1', 0, 'HB24A207', 9, 3), (10, 'BCG', 'DU', 2, 'BCG2410', 9, 3),
 (11, 'HEPB', 'D1', 0, 'HB24A207', 9, 3), (11, 'BCG', 'DU', 2, 'BCG2410', 9, 3),
 (12, 'HEPB', 'D1', 0, 'HB24A099', 9, 3), (12, 'BCG', 'DU', 1, 'BCG2398', 9, 3),
 (13, 'HEPB', 'D1', 5, 'HB24A207', 8, 1)
) AS v (crianca_id, sigla, dose, dia_vida, lote, profissional_id, unidade_id)
JOIN cadastro.crianca c  ON c.crianca_id = v.crianca_id
JOIN dominio.vacina  vac ON vac.sigla    = v.sigla;
GO
PRINT 'Agenda, consultas e vacinas carregadas.';
GO
