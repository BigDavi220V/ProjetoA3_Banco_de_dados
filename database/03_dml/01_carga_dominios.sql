/* =====================================================================
   01_carga_dominios.sql  —  DML: povoamento das tabelas de domínio
   ---------------------------------------------------------------------
   Valores tirados diretamente dos formulários da Caderneta da Criança
   (Anexos I.a e I.b do documento de Redesenho).
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

INSERT INTO dominio.especialidade (nome, descricao) VALUES
 (N'Pediatria',                      N'Acompanhamento do crescimento e desenvolvimento infantil'),
 (N'Neonatologia',                   N'Cuidado do recém-nascido, inclusive em UTI neonatal'),
 (N'Obstetrícia',                    N'Pré-natal e parto'),
 (N'Enfermagem Obstétrica',          N'Pré-natal de risco habitual e parto normal'),
 (N'Enfermagem em Saúde da Criança', N'Puericultura, triagens e consulta da 1ª semana'),
 (N'Oftalmologia',                   N'Teste do olhinho e acompanhamento visual'),
 (N'Fonoaudiologia',                 N'Triagem auditiva (teste da orelhinha)'),
 (N'Saúde da Família',               N'Atenção primária na UBS/USF e visita domiciliar');
GO

INSERT INTO dominio.categoria_profissional (nome, conselho, pode_assinar_clinico) VALUES
 (N'Médico(a)',                   'CRM',    1),
 (N'Enfermeiro(a)',               'COREN',  1),
 (N'Técnico(a) de Enfermagem',    'COREN',  1),
 (N'Fonoaudiólogo(a)',            'CRFa',   1),
 (N'Agente Administrativo',       'NENHUM', 0);
GO

-- Agravos do quadro de sorologias (CID-10)
INSERT INTO dominio.agravo (cid10, nome) VALUES
 ('A53',   N'Sífilis'),
 ('B18',   N'Hepatite viral crônica (B/C)'),
 ('B58',   N'Toxoplasmose'),
 ('A92.5', N'Doença pelo vírus Zika');
GO

INSERT INTO dominio.vacina (sigla, nome, publico_alvo) VALUES
 ('DTPA',      N'dTpa (difteria, tétano e coqueluche acelular)', 'GESTANTE'),
 ('INFLUENZA', N'Influenza',                                     'GESTANTE'),
 ('HEPB',      N'Hepatite B',                                    'AMBOS'),
 ('COVID19',   N'Covid-19',                                      'GESTANTE'),
 ('BCG',       N'BCG',                                           'CRIANCA');
GO

INSERT INTO dominio.tipo_triagem (codigo, nome, nome_popular, orientacao_prazo, prazo_max_dias, avalia_lateralidade) VALUES
 ('REFLEXO_VERMELHO', N'Teste do reflexo vermelho',                 N'do olhinho',
     N'Deve ser realizado antes da alta da maternidade', 7, 1),
 ('OXIMETRIA',        N'Triagem de cardiopatia congênita crítica', N'do coraçãozinho',
     N'Realizado na maternidade após 24h de vida', 7, 0),
 ('AUDITIVA',         N'Triagem auditiva',                          N'da orelhinha',
     N'Preferencialmente entre 24 e 48h de vida; no máximo durante o 1º mês', 30, 1),
 ('BIOLOGICA',        N'Triagem biológica',                         N'do pezinho',
     N'Idealmente entre o 3º e o 5º dia de vida', 5, 0);
GO

INSERT INTO dominio.sinal_alerta (nome, criterio, ordem_exibicao) VALUES
 (N'Coto umbilical infeccionado',           NULL,                 1),
 (N'Icterícia',                             NULL,                 2),
 (N'Diarreia/vômitos',                      NULL,                 3),
 (N'Dificuldade para respirar',             N'FR > 60 ou < 30',   4),
 (N'Febre',                                 N'≥ 37,5 °C',         5),
 (N'Hipotermia',                            N'< 36,5 °C',         6),
 (N'Convulsões ou movimentos anormais',     NULL,                 7),
 (N'Ausculta cardíaca alterada/cianose',    NULL,                 8);
GO

INSERT INTO dominio.setor_internacao (sigla, nome) VALUES
 ('UTIN',   N'Unidade de Terapia Intensiva Neonatal'),
 ('UCINCO', N'Unidade de Cuidado Intermediário Neonatal Convencional'),
 ('UCINCA', N'Unidade de Cuidado Intermediário Neonatal Canguru'),
 ('ALCON',  N'Alojamento Conjunto');
GO

/* Referência peso x IG (percentis 10 e 90, valores aproximados, uso acadêmico).
   Exemplo de INSERT com VALUES em lote + tabela derivada para os dois sexos. */
INSERT INTO dominio.referencia_peso_ig (ig_semanas, sexo, p10_g, p90_g)
SELECT v.ig, v.sexo, v.p10, v.p90
FROM (VALUES
 (24,'M', 540, 800),(24,'F', 500, 760),
 (25,'M', 610, 920),(25,'F', 570, 860),
 (26,'M', 700,1050),(26,'F', 650, 980),
 (27,'M', 790,1190),(27,'F', 730,1110),
 (28,'M', 890,1340),(28,'F', 820,1250),
 (29,'M',1000,1500),(29,'F', 920,1410),
 (30,'M',1130,1680),(30,'F',1040,1580),
 (31,'M',1270,1880),(31,'F',1170,1770),
 (32,'M',1430,2090),(32,'F',1320,1970),
 (33,'M',1600,2320),(33,'F',1490,2200),
 (34,'M',1790,2570),(34,'F',1680,2450),
 (35,'M',2000,2830),(35,'F',1880,2700),
 (36,'M',2230,3100),(36,'F',2100,2960),
 (37,'M',2450,3400),(37,'F',2340,3260),
 (38,'M',2660,3680),(38,'F',2550,3530),
 (39,'M',2840,3900),(39,'F',2720,3750),
 (40,'M',2980,4070),(40,'F',2850,3920),
 (41,'M',3090,4200),(41,'F',2950,4050),
 (42,'M',3170,4300),(42,'F',3020,4140)
) AS v (ig, sexo, p10, p90);
GO
PRINT 'Domínios carregados.';
GO
