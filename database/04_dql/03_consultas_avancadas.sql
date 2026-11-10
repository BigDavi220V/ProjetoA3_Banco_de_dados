/* =====================================================================
   03_consultas_avancadas.sql  —  DQL: recursos avançados do T-SQL
   ---------------------------------------------------------------------
   CTE, funções de janela, PIVOT, subconsulta correlacionada, JSON,
   funções e procedures criadas pelo grupo.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* Q14 — Ganho de peso desde o nascimento até a ÚLTIMA consulta.
   CTE (WITH) + ROW_NUMBER() OVER (PARTITION BY ...) numera as consultas
   de cada criança da mais recente para a mais antiga; ficamos com a 1ª. */
WITH ultima_consulta AS (
    SELECT co.crianca_id, co.data_consulta, co.peso_g,
           ROW_NUMBER() OVER (PARTITION BY co.crianca_id ORDER BY co.data_consulta DESC) AS ordem
    FROM atendimento.consulta co
    WHERE co.peso_g IS NOT NULL
)
SELECT  c.nome,
        n.peso_g                              AS peso_nascer_g,
        u.peso_g                              AS peso_atual_g,
        DATEDIFF(DAY, c.data_nascimento, u.data_consulta) AS dias,
        CAST(1.0 * (u.peso_g - n.peso_g)
             / NULLIF(DATEDIFF(DAY, c.data_nascimento, u.data_consulta), 0) AS DECIMAL(6,1)) AS ganho_g_dia
FROM ultima_consulta u
JOIN cadastro.crianca   c ON c.crianca_id = u.crianca_id
JOIN clinico.nascimento n ON n.crianca_id = u.crianca_id
WHERE u.ordem = 1
ORDER BY ganho_g_dia;
GO

/* Q15 — O quadro de sorologias "como no papel" (linhas = agravos,
   colunas = trimestres) usando PIVOT. Prova que a normalização não
   perde informação: a grade original é reconstruída a qualquer momento. */
DECLARE @gestacao INT = 3;   -- gestação com toxoplasmose alterada no 2º trimestre

SELECT agravo, [1] AS trimestre_1, [2] AS trimestre_2, [3] AS trimestre_3
FROM (
    SELECT CONCAT(a.cid10, ' - ', a.nome) AS agravo, s.trimestre, s.resultado
    FROM clinico.sorologia_prenatal s
    JOIN dominio.agravo a ON a.agravo_id = s.agravo_id
    WHERE s.gestacao_id = @gestacao
) AS origem
PIVOT (MAX(resultado) FOR trimestre IN ([1],[2],[3])) AS grade
ORDER BY agravo;
GO

/* Q16 — Profissionais com produção ACIMA da média
   (subconsulta na cláusula HAVING calcula a média geral) */
SELECT  p.nome, COUNT(*) AS atendimentos
FROM atendimento.consulta co
JOIN cadastro.profissional p ON p.profissional_id = co.profissional_id
GROUP BY p.nome
HAVING COUNT(*) > (SELECT AVG(CAST(qtd AS DECIMAL(6,2)))
                   FROM (SELECT COUNT(*) AS qtd
                         FROM atendimento.consulta
                         GROUP BY profissional_id) AS por_profissional);
GO

/* Q17 — Absenteísmo: % de faltas sobre os agendamentos já vencidos, por unidade */
SELECT  u.nome AS unidade,
        COUNT(*) AS agendamentos_passados,
        SUM(CASE WHEN a.status = 'FALTOU' THEN 1 ELSE 0 END) AS faltas,
        CAST(100.0 * SUM(CASE WHEN a.status = 'FALTOU' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS absenteismo_pct
FROM atendimento.agendamento a
JOIN cadastro.unidade_saude u ON u.unidade_id = a.unidade_id
WHERE a.data_hora < CAST(GETDATE() AS DATE)
  AND a.status <> 'CANCELADO'
GROUP BY u.nome;
GO

/* Q18 — Auditoria: quem mudou o quê. JSON_VALUE lê um campo de dentro
   do JSON gravado pelo trigger (antes x depois do status). */
SELECT TOP (20)
        l.data_hora,
        l.tabela,
        l.operacao,
        l.chave,
        ISNULL(us.nome_exibicao, N'(script / sistema)')   AS usuario,
        JSON_VALUE(l.dados_antes,  '$.status')            AS status_antes,
        JSON_VALUE(l.dados_depois, '$.status')            AS status_depois
FROM auditoria.log_auditoria l
LEFT JOIN seguranca.usuario us ON us.usuario_id = l.usuario_id
WHERE l.tabela = N'atendimento.agendamento'
ORDER BY l.log_id DESC;
GO

/* Q19 — Usando as FUNÇÕES do grupo direto num SELECT */
SELECT  c.nome, c.sexo, n.ig_semanas, n.peso_g,
        clinico.fn_classificar_peso_ig(n.peso_g, n.ig_semanas, c.sexo) AS adequacao,
        clinico.fn_idade_em_dias(c.data_nascimento, NULL)            AS idade_dias
FROM cadastro.crianca c
JOIN clinico.nascimento n ON n.crianca_id = c.crianca_id
ORDER BY adequacao, c.nome;
GO

/* Q20 — Chamando a PROCEDURE de relatório (mesmo resultado da Q7) */
DECLARE @ini DATE = DATEADD(DAY, -60, CAST(GETDATE() AS DATE)),
        @fim DATE = CAST(GETDATE() AS DATE);
EXEC relatorio.sp_atendimentos_por_especialidade @inicio = @ini, @fim = @fim;
GO
