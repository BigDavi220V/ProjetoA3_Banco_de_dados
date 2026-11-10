/* =====================================================================
   03_carga_gestacao_nascimento.sql  —  DML: Anexo I.b
   Gestação, sorologias, vacinas do pré-natal, parto, crianças,
   nascimento, internação neonatal e alta.
   ---------------------------------------------------------------------
   Casos de teste propositais (para a demonstração):
     criança 3  -> prematuro tardio, internado na UCINCo
     criança 4  -> mãe adolescente (17 anos), PIG, Coombs direto positivo
     criança 5  -> GIG (4.250 g), mãe com diabetes gestacional
     criança 8  -> prematuro de 32 semanas, Apgar 5/6, UTIN + UCINCo + Canguru
     crianças 10 e 11 -> gêmeas (mesma gestação e mesmo parto)
     criança 13 -> parto domiciliar, sem profilaxias, sem alta de maternidade
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* ---------- GESTAÇÕES (uma por mãe; a 10 é gemelar) ---------- */
DECLARE @hoje DATE = CAST(GETDATE() AS DATE);

SET IDENTITY_INSERT clinico.gestacao ON;
INSERT INTO clinico.gestacao
    (gestacao_id, gestante_id, data_registro, dum, planejada, fez_prenatal, numero_consultas,
     trimestre_inicio, tipo_gravidez, gravidez_risco, risco_descricao, coombs_indireto)
VALUES
 ( 1,  1, DATEADD(DAY,-250,@hoje), DATEADD(DAY,-(4+275),@hoje),  1, 1,  8, 1, 'UNICA',    0, NULL, 'NEGATIVO'),
 ( 2,  2, DATEADD(DAY,-255,@hoje), DATEADD(DAY,-(6+281),@hoje),  0, 1,  7, 1, 'UNICA',    0, NULL, 'NEGATIVO'),
 ( 3,  3, DATEADD(DAY,-180,@hoje), DATEADD(DAY,-(12+248),@hoje), 0, 1,  4, 2, 'UNICA',    1, N'Hipertensão gestacional', 'NEGATIVO'),
 ( 4,  4, DATEADD(DAY, -90,@hoje), DATEADD(DAY,-(9+270),@hoje),  0, 1,  3, 3, 'UNICA',    1, N'Gestante adolescente; anemia', 'POSITIVO'),
 ( 5,  5, DATEADD(DAY,-260,@hoje), DATEADD(DAY,-(14+280),@hoje), 1, 1,  9, 1, 'UNICA',    1, N'Diabetes mellitus gestacional', 'NEGATIVO'),
 ( 6,  6, DATEADD(DAY,-265,@hoje), DATEADD(DAY,-(20+278),@hoje), 1, 1,  6, 1, 'UNICA',    0, NULL, 'NEGATIVO'),
 ( 7,  7, DATEADD(DAY,-240,@hoje), DATEADD(DAY,-(2+273),@hoje),  1, 1,  7, 1, 'UNICA',    0, NULL, 'NEGATIVO'),
 ( 8,  8, DATEADD(DAY,-200,@hoje), DATEADD(DAY,-(30+225),@hoje), 0, 1,  5, 2, 'UNICA',    1, N'Idade materna avançada; pré-eclâmpsia', 'NEGATIVO'),
 ( 9,  9, DATEADD(DAY, -50,@hoje), NULL,                          0, 0, NULL, NULL, 'UNICA', NULL, NULL, 'NAO_REALIZADO'),
 (10, 10, DATEADD(DAY,-230,@hoje), DATEADD(DAY,-(3+254),@hoje),  1, 1, 10, 1, 'MULTIPLA', 1, N'Gestação gemelar dicoriônica', 'NEGATIVO'),
 (11, 11, DATEADD(DAY,-320,@hoje), DATEADD(DAY,-(60+276),@hoje), 1, 1,  8, 1, 'UNICA',    0, NULL, 'NEGATIVO'),
 (12, 12, DATEADD(DAY,-170,@hoje), DATEADD(DAY,-(7+282),@hoje),  0, 1,  6, 2, 'UNICA',    0, NULL, 'NAO_REALIZADO');
SET IDENTITY_INSERT clinico.gestacao OFF;
GO

/* ---------- SOROLOGIAS: INSERT ... SELECT com CROSS JOIN ----------
   Gera a grade inteira (agravo x trimestre) para quem fez pré-natal,
   apenas a partir do trimestre em que a mãe começou as consultas.
   Os CASEs marcam alguns resultados especiais. */
INSERT INTO clinico.sorologia_prenatal (gestacao_id, agravo_id, trimestre, resultado)
SELECT g.gestacao_id,
       a.agravo_id,
       t.trimestre,
       CASE
           WHEN g.gestacao_id = 4 AND a.cid10 = 'A53'   AND t.trimestre = 3 THEN 'ALT'  -- sífilis na gestante adolescente
           WHEN g.gestacao_id = 3 AND a.cid10 = 'B58'   AND t.trimestre = 2 THEN 'ALT'  -- toxoplasmose
           WHEN a.cid10 = 'A92.5' AND t.trimestre = 3                      THEN 'NR'   -- Zika não repetido no 3º tri
           WHEN g.gestacao_id = 12 AND t.trimestre = 3                     THEN 'NR'
           ELSE 'N'
       END
FROM clinico.gestacao g
CROSS JOIN dominio.agravo a
CROSS JOIN (VALUES (1),(2),(3)) AS t (trimestre)
WHERE g.fez_prenatal = 1
  AND t.trimestre >= g.trimestre_inicio;
GO

/* ---------- VACINAS DO PRÉ-NATAL ---------- */
INSERT INTO clinico.vacina_prenatal (gestacao_id, vacina_id, recebeu)
SELECT g.gestacao_id,
       v.vacina_id,
       CASE
           WHEN g.gestacao_id = 4  AND v.sigla IN ('COVID19','INFLUENZA') THEN 0
           WHEN g.gestacao_id = 12 AND v.sigla = 'DTPA'                   THEN 0
           WHEN g.gestacao_id = 3  AND v.sigla = 'COVID19'                THEN 0
           ELSE 1
       END
FROM clinico.gestacao g
CROSS JOIN dominio.vacina v
WHERE g.fez_prenatal = 1
  AND v.publico_alvo IN ('GESTANTE','AMBOS');
GO

/* ---------- PARTOS ---------- */
DECLARE @hoje DATE = CAST(GETDATE() AS DATE);
INSERT INTO clinico.parto
    (gestacao_id, data_parto, local_tipo, unidade_id, local_descricao, tipo_parto, motivo_cesarea, teve_acompanhante, acompanhante_descricao)
VALUES
 ( 1, DATEADD(DAY, -4,@hoje), 'HOSPITAL',            3, NULL, 'VAGINAL', NULL, 1, N'Companheiro'),
 ( 2, DATEADD(DAY, -6,@hoje), 'HOSPITAL',            3, NULL, 'VAGINAL', NULL, 1, N'Mãe da parturiente'),
 ( 3, DATEADD(DAY,-12,@hoje), 'HOSPITAL',            5, NULL, 'CESAREA', N'Síndrome hipertensiva com piora clínica', 1, N'Irmã'),
 ( 4, DATEADD(DAY, -9,@hoje), 'HOSPITAL',            3, NULL, 'VAGINAL', NULL, 0, NULL),
 ( 5, DATEADD(DAY,-14,@hoje), 'HOSPITAL',            3, NULL, 'CESAREA', N'Macrossomia fetal estimada', 1, N'Companheiro'),
 ( 6, DATEADD(DAY,-20,@hoje), 'CENTRO_PARTO_NORMAL', 4, NULL, 'VAGINAL', NULL, 1, N'Doula e companheiro'),
 ( 7, DATEADD(DAY, -2,@hoje), 'HOSPITAL',            3, NULL, 'VAGINAL', NULL, 1, N'Companheiro'),
 ( 8, DATEADD(DAY,-30,@hoje), 'HOSPITAL',            5, NULL, 'CESAREA', N'Pré-eclâmpsia grave', 1, N'Companheiro'),
 ( 9, DATEADD(DAY,-45,@hoje), 'HOSPITAL',            3, NULL, 'VAGINAL', NULL, 0, NULL),
 (10, DATEADD(DAY, -3,@hoje), 'HOSPITAL',            3, NULL, 'CESAREA', N'Gestação gemelar com 1º feto pélvico', 1, N'Companheiro'),
 (11, DATEADD(DAY,-60,@hoje), 'HOSPITAL',            3, NULL, 'VAGINAL', NULL, 1, N'Mãe da parturiente'),
 (12, DATEADD(DAY, -7,@hoje), 'DOMICILIO',        NULL, N'Residência da família — parto rápido, SAMU chegou após o nascimento', 'VAGINAL', NULL, 1, N'Companheiro');
GO

/* ---------- CRIANÇAS (o trigger abre o prontuário de cada uma) ---------- */
DECLARE @hoje DATE = CAST(GETDATE() AS DATE);
SET IDENTITY_INSERT cadastro.crianca ON;
INSERT INTO cadastro.crianca
    (crianca_id, gestacao_id, nome, sexo, data_nascimento, cns, tipo_sanguineo, fator_rh, unidade_referencia_id)
VALUES
 ( 1,  1, N'Miguel Santos Oliveira',      'M', DATEADD(DAY, -4,@hoje), '800000000000101', 'A',  '+', 1),
 ( 2,  2, N'Helena Souza Lima',           'F', DATEADD(DAY, -6,@hoje), '800000000000202', 'O',  '+', 1),
 ( 3,  3, N'Arthur Conceição Pereira',    'M', DATEADD(DAY,-12,@hoje), '800000000000303', 'B',  '+', 2),
 ( 4,  4, N'Laura Bispo Nascimento',      'F', DATEADD(DAY, -9,@hoje), NULL,              'A',  '+', 1),
 ( 5,  5, N'Gael Ferreira Santana',       'M', DATEADD(DAY,-14,@hoje), '800000000000505', 'AB', '+', 2),
 ( 6,  6, N'Alice Rocha Barbosa',         'F', DATEADD(DAY,-20,@hoje), '800000000000606', 'A',  '+', 1),
 ( 7,  7, N'Théo Almeida Cruz',           'M', DATEADD(DAY, -2,@hoje), NULL,              NULL, NULL, 1),
 ( 8,  8, N'Cecília Araújo Matos',        'F', DATEADD(DAY,-30,@hoje), '800000000000808', 'B',  '+', 2),
 ( 9,  9, N'Ravi Teixeira Moura',         'M', DATEADD(DAY,-45,@hoje), '800000000000909', 'O',  '+', 2),
 (10, 10, N'Maria Clara Lopes Silva',     'F', DATEADD(DAY, -3,@hoje), '800000000001010', 'A',  '+', 1),
 (11, 10, N'Maria Luísa Lopes Silva',     'F', DATEADD(DAY, -3,@hoje), '800000000001011', 'A',  '+', 1),
 (12, 11, N'Benício Nunes Carvalho',      'M', DATEADD(DAY,-60,@hoje), '800000000001212', 'O',  '-', 2),
 (13, 12, N'Aurora Menezes Dias',         'F', DATEADD(DAY, -7,@hoje), NULL,              NULL, NULL, 1);
SET IDENTITY_INSERT cadastro.crianca OFF;
GO

/* ---------- NASCIMENTO (um por bebê) ---------- */
INSERT INTO clinico.nascimento
    (crianca_id, hora_nascimento, contato_pele_a_pele, mamou_primeira_hora, apgar_1min, apgar_5min,
     clampeamento_oportuno, ig_semanas, ig_dias, ig_metodo, peso_g, comprimento_cm, perimetro_cefalico_cm,
     reanimacao, assistido_por_id, coombs_direto, profilaxia_oftalmica, vitamina_k, registrado_por_id)
VALUES
 ( 1, '08:42', 1, 1, 8,  9, 1, 39, 2, 'USG', 3250, 49.5, 34.0, 0,    2, 'NEGATIVO',      1, 1, 6),
 ( 2, '14:10', 1, 1, 9, 10, 1, 40, 1, 'DUM', 3420, 50.0, 34.5, 0,    2, 'NAO_REALIZADO', 1, 1, 6),
 ( 3, '03:25', 0, 0, 7,  8, 0, 35, 3, 'USG', 2280, 45.0, 31.5, 0,    2, 'NEGATIVO',      1, 1, 6),
 ( 4, '22:05', 1, 1, 8,  9, 1, 38, 4, 'USG', 2400, 46.0, 32.0, 0,    2, 'POSITIVO',      1, 1, 6),
 ( 5, '10:30', 0, 0, 8,  9, 1, 40, 0, 'USG', 4250, 53.0, 36.0, 0,    2, 'NEGATIVO',      1, 1, 6),
 ( 6, '06:15', 1, 1, 9, 10, 1, 39, 5, 'DUM', 3100, 48.5, 33.5, 0,    6, 'NAO_REALIZADO', 1, 1, 6),
 ( 7, '19:50', 1, 1, 9,  9, 1, 39, 0, 'USG', 3380, 50.5, 34.5, 0,    2, 'NEGATIVO',      1, 1, 6),
 ( 8, '11:05', 0, 0, 5,  6, 0, 32, 1, 'USG', 1650, 41.0, 29.5, 1,    2, 'NEGATIVO',      1, 1, 6),
 ( 9, '16:40', 1, 0, 8,  9, 1, 41, 0, 'DUM', 3600, 51.0, 35.0, 0,    2, 'NAO_REALIZADO', 1, 1, 6),
 (10, '09:00', 1, 1, 8,  9, 1, 36, 2, 'USG', 2350, 45.5, 32.0, 0,    2, 'NEGATIVO',      1, 1, 6),
 (11, '09:03', 1, 0, 7,  9, 1, 36, 2, 'USG', 2210, 45.0, 31.5, 0,    2, 'NEGATIVO',      1, 1, 6),
 (12, '13:20', 1, 1, 9, 10, 1, 39, 3, 'USG', 3550, 50.0, 35.0, 0,    2, 'NEGATIVO',      1, 1, 6),
 (13, '04:10', 1, 1, 8,  9, 1, 40, 2, 'DUM', 3300, 49.0, 34.0, 0, NULL, NULL,            0, 0, 5);
GO

/* ---------- INTERNAÇÃO NEONATAL + SETORES (multivalorado) ---------- */
DECLARE @hoje DATE = CAST(GETDATE() AS DATE);
INSERT INTO clinico.internacao_neonatal (crianca_id, motivo, data_inicio) VALUES
 (3, N'Prematuridade tardia e desconforto respiratório leve',                       DATEADD(DAY,-12,@hoje)),
 (5, N'Hipoglicemia neonatal (filho de mãe diabética) — observação',              DATEADD(DAY,-14,@hoje)),
 (8, N'Prematuridade de 32 semanas, desconforto respiratório e reanimação ao nascer', DATEADD(DAY,-30,@hoje));
GO

-- INSERT ... SELECT com JOIN: busca os IDs pelos códigos (sem "chutar" números)
INSERT INTO clinico.internacao_setor (internacao_id, setor_id, dias)
SELECT i.internacao_id, s.setor_id, v.dias
FROM (VALUES (3,'UCINCO',5),
             (5,'ALCON', 3),
             (8,'UTIN', 12),
             (8,'UCINCO',6),
             (8,'UCINCA',4)) AS v (crianca_id, sigla, dias)
JOIN clinico.internacao_neonatal i ON i.crianca_id = v.crianca_id
JOIN dominio.setor_internacao    s ON s.sigla      = v.sigla;
GO

/* ---------- ALTA DA MATERNIDADE ----------
   Sem alta: criança 7 (ainda na maternidade) e 13 (nasceu em casa). */
INSERT INTO clinico.alta_maternidade (crianca_id, data_alta, peso_alta_g, comprimento_alta_cm, aleitamento, resumo_alta, registrado_por_id)
SELECT c.crianca_id, DATEADD(DAY, v.dias_ate_alta, c.data_nascimento), v.peso, v.comp, v.aleit, v.resumo, 2
FROM (VALUES
 ( 1, 2, 3120, 49.5, 'LME',   N'Sem intercorrências. Retorno na UBS na 1ª semana.'),
 ( 2, 2, 3290, 50.0, 'LME',   N'Sem intercorrências.'),
 ( 3, 6, 2190, 45.0, 'LME',   N'Desconforto respiratório resolvido. Acompanhar ganho de peso semanal.'),
 ( 4, 3, 2310, 46.0, 'LME',   N'Coombs direto positivo, fototerapia por 48h. Sífilis materna tratada: acompanhar VDRL do RN.'),
 ( 5, 4, 4080, 53.0, 'LM_LA', N'Hipoglicemia corrigida. Manter glicemia capilar se sintomas.'),
 ( 6, 1, 3010, 48.5, 'LME',   N'Parto em centro de parto normal, alta em 24h.'),
 ( 8,23, 1890, 42.5, 'LM_LA', N'Prematura 32s. Seguimento de risco: ambulatório de egressos, oftalmologia (ROP) e fonoaudiologia.'),
 ( 9, 2, 3480, 51.0, 'LME',   N'Mãe sem pré-natal: sorologias do RN colhidas na maternidade, todas negativas.'),
 (10, 4, 2260, 45.5, 'LME',   N'Gemelar. Boa sucção.'),
 (11, 4, 2120, 45.0, 'LM_LA', N'Gemelar. Complemento por baixo ganho ponderal, reavaliar na 1ª semana.'),
 (12, 2, 3400, 50.0, 'LME',   N'Sem intercorrências.')
) AS v (crianca_id, dias_ate_alta, peso, comp, aleit, resumo)
JOIN cadastro.crianca c ON c.crianca_id = v.crianca_id;
GO
PRINT 'Gestação, parto, nascimento e alta carregados.';
GO
