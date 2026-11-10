/* =====================================================================
   04_carga_triagens.sql  —  DML: Anexo I.a (Triagens Neonatais)
   ---------------------------------------------------------------------
   Padrão usado: uma tabela derivada (VALUES) com "dia de vida" em vez
   de data fixa, unida (JOIN) com crianca e tipo_triagem para converter
   códigos em IDs e dias em datas reais.
   Casos de teste:
     criança 4  -> olhinho ALTERADO no olho esquerdo
     criança 5  -> orelhinha ALTERADA no ouvido esquerdo (reteste)
     criança 3  -> coraçãozinho alterado na 1ª aferição e normal na 2ª
     criança 11 -> coraçãozinho alterado na 1ª aferição (resultado: REPETIR)
     criança 8  -> coraçãozinho NÃO realizado (estava na UTIN)
     crianças 1, 7, 10, 11, 13 -> triagens ainda pendentes
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

INSERT INTO clinico.triagem_neonatal
    (crianca_id, tipo_triagem_id, realizada, data_realizacao, metodo, data_reteste, conduta, profissional_id)
SELECT c.crianca_id,
       tt.tipo_triagem_id,
       v.realizada,
       CASE WHEN v.realizada = 1 THEN DATEADD(DAY, v.dia_vida, c.data_nascimento) END,
       v.metodo,
       CASE WHEN v.dia_reteste IS NOT NULL THEN DATEADD(DAY, v.dia_reteste, c.data_nascimento) END,
       v.conduta,
       v.profissional_id
FROM (VALUES
 -- criança, tipo,             realizada, dia, método, reteste, conduta, profissional
 ( 1, 'REFLEXO_VERMELHO', 1, 1, NULL,    NULL, NULL, 2),
 ( 1, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 ( 1, 'AUDITIVA',         1, 2, 'EOA',   NULL, NULL, 10),
 ( 2, 'REFLEXO_VERMELHO', 1, 1, NULL,    NULL, NULL, 2),
 ( 2, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 ( 2, 'AUDITIVA',         1, 1, 'EOA',   NULL, NULL, 10),
 ( 2, 'BIOLOGICA',        1, 4, NULL,    NULL, NULL, 8),
 ( 3, 'REFLEXO_VERMELHO', 1, 5, NULL,    NULL, NULL, 2),
 ( 3, 'OXIMETRIA',        1, 2, NULL,    NULL, N'1ª aferição alterada; 2ª aferição após 1h normal.', 6),
 ( 3, 'AUDITIVA',         1, 5, 'PEATE', NULL, N'PEATE por internação em UCIN.', 10),
 ( 3, 'BIOLOGICA',        1, 5, NULL,    NULL, NULL, 9),
 ( 4, 'REFLEXO_VERMELHO', 1, 2, NULL,    NULL, N'Reflexo ausente em OE. Encaminhado à oftalmologia com urgência.', 2),
 ( 4, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 ( 4, 'AUDITIVA',         1, 2, 'EOA',   NULL, NULL, 10),
 ( 4, 'BIOLOGICA',        1, 4, NULL,    9,    N'Amostra insuficiente; reteste colhido na UBS.', 8),
 ( 5, 'REFLEXO_VERMELHO', 1, 2, NULL,    NULL, NULL, 2),
 ( 5, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 ( 5, 'AUDITIVA',         1, 2, 'EOA',   NULL, N'Falha à esquerda. Reteste em até 30 dias.', 10),
 ( 5, 'BIOLOGICA',        1, 4, NULL,    NULL, NULL, 9),
 ( 6, 'REFLEXO_VERMELHO', 1, 1, NULL,    NULL, NULL, 6),
 ( 6, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 ( 6, 'AUDITIVA',         1, 6, 'EOA',   NULL, NULL, 10),
 ( 6, 'BIOLOGICA',        1, 4, NULL,    NULL, NULL, 8),
 ( 7, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 ( 8, 'REFLEXO_VERMELHO', 1,20, NULL,    NULL, NULL, 4),
 ( 8, 'OXIMETRIA',        0, 0, NULL,    NULL, N'Não indicado: RN em UTIN, avaliado com ecocardiograma.', NULL),
 ( 8, 'AUDITIVA',         1,21, 'PEATE', NULL, N'Falha à esquerda. Encaminhado ao serviço de saúde auditiva.', 10),
 ( 8, 'BIOLOGICA',        1, 5, NULL,    15,   N'Prematuro: 2ª coleta conforme protocolo.', 9),
 ( 9, 'REFLEXO_VERMELHO', 1, 1, NULL,    NULL, NULL, 2),
 ( 9, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 ( 9, 'AUDITIVA',         1, 1, 'EOA',   NULL, NULL, 10),
 ( 9, 'BIOLOGICA',        1, 3, NULL,    NULL, NULL, 9),
 (10, 'REFLEXO_VERMELHO', 1, 1, NULL,    NULL, NULL, 2),
 (10, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 (10, 'AUDITIVA',         1, 2, 'EOA',   NULL, NULL, 10),
 (11, 'REFLEXO_VERMELHO', 1, 1, NULL,    NULL, NULL, 2),
 (11, 'OXIMETRIA',        1, 1, NULL,    NULL, N'1ª aferição alterada. Repetir após 1 hora.', 6),
 (12, 'REFLEXO_VERMELHO', 1, 1, NULL,    NULL, NULL, 2),
 (12, 'OXIMETRIA',        1, 1, NULL,    NULL, NULL, 6),
 (12, 'AUDITIVA',         1, 1, 'EOA',   NULL, NULL, 10),
 (12, 'BIOLOGICA',        1, 4, NULL,    NULL, NULL, 9),
 (13, 'BIOLOGICA',        1, 5, NULL,    NULL, N'Coletado na USF (parto domiciliar).', 8)
) AS v (crianca_id, codigo, realizada, dia_vida, metodo, dia_reteste, conduta, profissional_id)
JOIN cadastro.crianca     c  ON c.crianca_id = v.crianca_id
JOIN dominio.tipo_triagem tt ON tt.codigo    = v.codigo;
GO

/* Resultado por lado (olhinho e orelhinha) */
INSERT INTO clinico.triagem_resultado_lado (triagem_id, lado, resultado)
SELECT t.triagem_id, l.lado,
       CASE
           WHEN t.crianca_id = 4 AND tt.codigo = 'REFLEXO_VERMELHO' AND l.lado = 'E' THEN 'ALTERADO'
           WHEN t.crianca_id = 5 AND tt.codigo = 'AUDITIVA'         AND l.lado = 'E' THEN 'ALTERADO'
           WHEN t.crianca_id = 8 AND tt.codigo = 'AUDITIVA'         AND l.lado = 'E' THEN 'ALTERADO'
           ELSE 'NORMAL'
       END
FROM clinico.triagem_neonatal t
JOIN dominio.tipo_triagem tt ON tt.tipo_triagem_id = t.tipo_triagem_id
CROSS JOIN (VALUES ('D'),('E')) AS l (lado)
WHERE tt.avalia_lateralidade = 1
  AND t.realizada = 1;
GO

/* Aferições da oximetria de pulso (teste do coraçãozinho) */
INSERT INTO clinico.oximetria_afericao (triagem_id, numero_afericao, spo2_mao_direita, spo2_pe, aferido_em)
SELECT t.triagem_id, v.numero, v.mao, v.pe,
       DATEADD(HOUR, v.horas_de_vida, CAST(c.data_nascimento AS DATETIME2(0)))
FROM (VALUES
 ( 1, 1, 98, 97, 30),
 ( 2, 1, 99, 98, 28),
 ( 3, 1, 94, 97, 40),   -- mão 94% (< 95) -> repetir
 ( 3, 2, 97, 96, 41),   -- 2ª aferição normal
 ( 4, 1, 98, 98, 26),
 ( 5, 1, 97, 96, 30),
 ( 6, 1, 99, 99, 25),
 ( 7, 1, 98, 97, 27),
 ( 9, 1, 98, 98, 29),
 (10, 1, 97, 97, 26),
 (11, 1, 96, 92, 26),   -- diferença de 4% -> repetir
 (12, 1, 99, 98, 30)
) AS v (crianca_id, numero, mao, pe, horas_de_vida)
JOIN cadastro.crianca         c  ON c.crianca_id = v.crianca_id
JOIN dominio.tipo_triagem     tt ON tt.codigo = 'OXIMETRIA'
JOIN clinico.triagem_neonatal t  ON t.crianca_id = c.crianca_id
                                AND t.tipo_triagem_id = tt.tipo_triagem_id;
GO
PRINT 'Triagens neonatais carregadas.';
GO
