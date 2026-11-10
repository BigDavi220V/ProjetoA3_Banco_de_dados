/* =====================================================================
   02_views.sql  —  Views (consultas salvas, "tabelas virtuais")
   ---------------------------------------------------------------------
   A aplicação LÊ principalmente pelas views. Vantagens:
   - os JOINs complexos ficam escritos uma vez só, no banco;
   - campos calculados (idade, AIG/PIG/GIG, alertas) não são guardados
     em tabela (respeita a 3FN) mas aparecem prontos para a tela.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* Resumo da criança + mãe + nascimento + alertas de "cuidado especial"
   (quadro verde do Anexo I.a: peso < 2.500 g, < 37 semanas, Apgar < 7
   no 5º minuto, mãe adolescente, internação em UTI...) */
CREATE OR ALTER VIEW cadastro.vw_crianca_resumo
AS
SELECT
    c.crianca_id,
    c.nome,
    c.sexo,
    c.data_nascimento,
    c.cns,
    c.tipo_sanguineo,
    c.fator_rh,
    c.ativo,
    c.motivo_inativacao,
    clinico.fn_idade_em_dias(c.data_nascimento, NULL)            AS idade_dias,
    p.numero                                                     AS prontuario_numero,
    c.gestacao_id,
    ge.gestante_id,
    ge.nome                                                      AS mae_nome,
    ge.cpf                                                       AS mae_cpf,
    m.idade_mae_no_parto,
    u.unidade_id,
    u.nome                                                       AS unidade_nome,
    n.peso_g                                                     AS peso_nascer_g,
    n.ig_semanas,
    n.ig_dias,
    n.apgar_1min,
    n.apgar_5min,
    clinico.fn_classificar_peso_ig(n.peso_g, n.ig_semanas, c.sexo) AS adequacao_peso_ig,
    f.alerta_baixo_peso,
    f.alerta_prematuro,
    f.alerta_apgar_baixo,
    f.alerta_mae_adolescente,
    f.alerta_utin,
    CAST(CASE WHEN f.alerta_baixo_peso + f.alerta_prematuro + f.alerta_apgar_baixo
                 + f.alerta_mae_adolescente + f.alerta_utin > 0
              THEN 1 ELSE 0 END AS BIT)                          AS cuidado_especial
FROM cadastro.crianca            c
JOIN clinico.gestacao            g  ON g.gestacao_id  = c.gestacao_id
JOIN cadastro.gestante           ge ON ge.gestante_id = g.gestante_id
JOIN cadastro.unidade_saude      u  ON u.unidade_id   = c.unidade_referencia_id
LEFT JOIN clinico.prontuario     p  ON p.crianca_id   = c.crianca_id
LEFT JOIN clinico.nascimento     n  ON n.crianca_id   = c.crianca_id
-- idade exata da mãe no dia do nascimento (desconta se ainda não fez aniversário)
CROSS APPLY (
    SELECT DATEDIFF(YEAR, ge.data_nascimento, c.data_nascimento)
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, ge.data_nascimento, c.data_nascimento), ge.data_nascimento)
                     > c.data_nascimento THEN 1 ELSE 0 END AS idade_mae_no_parto
) m
CROSS APPLY (
    SELECT
        CASE WHEN n.peso_g     < 2500 THEN 1 ELSE 0 END AS alerta_baixo_peso,
        CASE WHEN n.ig_semanas < 37   THEN 1 ELSE 0 END AS alerta_prematuro,
        CASE WHEN n.apgar_5min < 7    THEN 1 ELSE 0 END AS alerta_apgar_baixo,
        CASE WHEN m.idade_mae_no_parto < 20 THEN 1 ELSE 0 END AS alerta_mae_adolescente,
        CASE WHEN EXISTS (SELECT 1
                          FROM clinico.internacao_neonatal i
                          JOIN clinico.internacao_setor    s  ON s.internacao_id = i.internacao_id
                          JOIN dominio.setor_internacao    si ON si.setor_id     = s.setor_id
                          WHERE i.crianca_id = c.crianca_id AND si.sigla = 'UTIN')
             THEN 1 ELSE 0 END AS alerta_utin
) f;
GO

/* Situação das 4 triagens de cada criança ativa.
   CROSS JOIN gera "criança x tipo de triagem" (todas as combinações);
   LEFT JOIN mostra o que foi feito e deixa NULL no que falta. */
CREATE OR ALTER VIEW clinico.vw_triagem_situacao
AS
SELECT
    c.crianca_id,
    c.nome                       AS crianca_nome,
    c.data_nascimento,
    c.unidade_referencia_id      AS unidade_id,
    tt.tipo_triagem_id,
    tt.codigo                    AS tipo_codigo,
    tt.nome_popular,
    tt.prazo_max_dias,
    t.triagem_id,
    t.realizada,
    t.data_realizacao,
    t.metodo,
    t.data_reteste,
    t.conduta,
    clinico.fn_resultado_triagem(t.triagem_id) AS resultado,
    CASE
        WHEN t.triagem_id IS NULL THEN
             CASE WHEN DATEDIFF(DAY, c.data_nascimento, CAST(GETDATE() AS DATE)) > tt.prazo_max_dias
                  THEN 'ATRASADA' ELSE 'PENDENTE' END
        WHEN t.realizada = 0 THEN 'NAO_REALIZADA'
        ELSE 'REALIZADA'
    END                          AS situacao
FROM cadastro.crianca c
CROSS JOIN dominio.tipo_triagem tt
LEFT JOIN clinico.triagem_neonatal t
       ON t.crianca_id = c.crianca_id
      AND t.tipo_triagem_id = tt.tipo_triagem_id
WHERE c.ativo = 1;
GO

/* Agenda com nomes prontos para exibição */
CREATE OR ALTER VIEW atendimento.vw_agenda_detalhada
AS
SELECT
    a.agendamento_id,
    a.data_hora,
    CAST(a.data_hora AS DATE)  AS data,
    a.duracao_min,
    a.tipo_atendimento,
    a.local_atendimento,
    a.status,
    a.motivo_cancelamento,
    a.observacao,
    a.crianca_id,
    c.nome                     AS crianca_nome,
    c.data_nascimento,
    clinico.fn_idade_em_dias(c.data_nascimento, CAST(a.data_hora AS DATE)) AS idade_dias_no_dia,
    ge.nome                    AS mae_nome,
    a.profissional_id,
    pr.nome                    AS profissional_nome,
    cat.nome                   AS categoria_nome,
    a.especialidade_id,
    e.nome                     AS especialidade_nome,
    a.unidade_id,
    u.nome                     AS unidade_nome,
    co.consulta_id
FROM atendimento.agendamento        a
JOIN cadastro.crianca               c   ON c.crianca_id       = a.crianca_id
JOIN clinico.gestacao               g   ON g.gestacao_id      = c.gestacao_id
JOIN cadastro.gestante              ge  ON ge.gestante_id     = g.gestante_id
JOIN cadastro.profissional          pr  ON pr.profissional_id = a.profissional_id
JOIN dominio.categoria_profissional cat ON cat.categoria_id   = pr.categoria_id
JOIN dominio.especialidade          e   ON e.especialidade_id = a.especialidade_id
JOIN cadastro.unidade_saude         u   ON u.unidade_id       = a.unidade_id
LEFT JOIN atendimento.consulta      co  ON co.agendamento_id  = a.agendamento_id;
GO

/* Linha do tempo do prontuário: junta eventos de 5 tabelas diferentes
   com UNION ALL (todas as partes precisam ter as mesmas colunas). */
CREATE OR ALTER VIEW clinico.vw_linha_tempo_crianca
AS
SELECT c.crianca_id,
       -- data + hora do nascimento (DATETIME2 não aceita "+", por isso DATEADD em segundos)
       DATEADD(SECOND,
               DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), ISNULL(n.hora_nascimento, CAST('00:00' AS TIME(0)))),
               CAST(c.data_nascimento AS DATETIME2(0))) AS data_evento,
       'NASCIMENTO' AS tipo_evento,
       N'Nascimento' AS titulo,
       CONCAT(N'Peso ', n.peso_g, N' g · IG ', n.ig_semanas, N's', n.ig_dias, N'd · Apgar ', n.apgar_1min, N'/', n.apgar_5min) AS detalhe,
       pa.nome AS profissional_nome
FROM cadastro.crianca c
JOIN clinico.nascimento n        ON n.crianca_id = c.crianca_id
LEFT JOIN cadastro.profissional pa ON pa.profissional_id = n.assistido_por_id

UNION ALL
SELECT a.crianca_id, CAST(a.data_alta AS DATETIME2(0)), 'ALTA', N'Alta da maternidade',
       CONCAT(N'Peso na alta ', a.peso_alta_g, N' g · Aleitamento: ', a.aleitamento),
       p.nome
FROM clinico.alta_maternidade a
LEFT JOIN cadastro.profissional p ON p.profissional_id = a.registrado_por_id

UNION ALL
SELECT t.crianca_id, CAST(t.data_realizacao AS DATETIME2(0)), 'TRIAGEM',
       CONCAT(N'Teste ', tt.nome_popular),
       ISNULL(clinico.fn_resultado_triagem(t.triagem_id), N'—'),
       p.nome
FROM clinico.triagem_neonatal t
JOIN dominio.tipo_triagem tt      ON tt.tipo_triagem_id = t.tipo_triagem_id
LEFT JOIN cadastro.profissional p ON p.profissional_id  = t.profissional_id
WHERE t.realizada = 1

UNION ALL
SELECT co.crianca_id, co.data_consulta, 'CONSULTA',
       CASE co.tipo_atendimento WHEN 'PRIMEIRA_SEMANA' THEN N'Consulta da 1ª semana'
                                ELSE CONCAT(N'Consulta · ', e.nome) END,
       CONCAT(N'Peso ', co.peso_g, N' g · PC ', co.perimetro_cefalico_cm, N' cm · ', e.nome),
       p.nome
FROM atendimento.consulta co
JOIN dominio.especialidade e  ON e.especialidade_id = co.especialidade_id
JOIN cadastro.profissional p  ON p.profissional_id  = co.profissional_id

UNION ALL
SELECT va.crianca_id, CAST(va.data_aplicacao AS DATETIME2(0)), 'VACINA',
       CONCAT(N'Vacina ', v.nome),
       CONCAT(N'Dose ', va.dose, N' · Lote ', ISNULL(va.lote, N'—')),
       p.nome
FROM atendimento.vacina_aplicada va
JOIN dominio.vacina v             ON v.vacina_id        = va.vacina_id
LEFT JOIN cadastro.profissional p ON p.profissional_id  = va.profissional_id;
GO

/* Gestão: atendimentos por especialidade e por mês */
CREATE OR ALTER VIEW relatorio.vw_atendimentos_especialidade_mes
AS
SELECT
    FORMAT(co.data_consulta, 'yyyy-MM') AS ano_mes,
    e.especialidade_id,
    e.nome                              AS especialidade,
    COUNT(*)                            AS total_consultas,
    COUNT(DISTINCT co.crianca_id)       AS criancas_atendidas,
    SUM(CASE WHEN co.local_atendimento = 'DOMICILIO' THEN 1 ELSE 0 END) AS em_domicilio
FROM atendimento.consulta co
JOIN dominio.especialidade e ON e.especialidade_id = co.especialidade_id
GROUP BY FORMAT(co.data_consulta, 'yyyy-MM'), e.especialidade_id, e.nome;
GO
PRINT 'Views criadas.';
GO
