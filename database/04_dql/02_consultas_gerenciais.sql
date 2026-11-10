/* =====================================================================
   02_consultas_gerenciais.sql  —  DQL: indicadores para a gestão
   ---------------------------------------------------------------------
   Agregações (GROUP BY, COUNT, AVG, SUM, HAVING) e filtros temporais.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* Q7 — Volume de atendimentos por especialidade em um intervalo
   (exemplo pedido no edital). Filtro temporal com intervalo semiaberto:
   >= início e < dia seguinte ao fim, para pegar o último dia inteiro. */
DECLARE @inicio DATE = DATEADD(DAY, -60, CAST(GETDATE() AS DATE)),
        @fim    DATE = CAST(GETDATE() AS DATE);

SELECT  e.nome                         AS especialidade,
        COUNT(co.consulta_id)          AS total_consultas,
        COUNT(DISTINCT co.crianca_id)  AS criancas_atendidas,
        SUM(CASE WHEN co.local_atendimento = 'DOMICILIO' THEN 1 ELSE 0 END) AS em_domicilio
FROM dominio.especialidade e
LEFT JOIN atendimento.consulta co
       ON co.especialidade_id = e.especialidade_id
      AND co.data_consulta >= @inicio
      AND co.data_consulta <  DATEADD(DAY, 1, @fim)
GROUP BY e.nome
ORDER BY total_consultas DESC;
GO

/* Q8 — Peso médio ao nascer e Apgar médio por tipo de parto (AVG) */
SELECT  pa.tipo_parto,
        COUNT(*)                                   AS nascimentos,
        CAST(AVG(CAST(n.peso_g AS DECIMAL(7,1))) AS DECIMAL(7,1))      AS peso_medio_g,
        CAST(AVG(CAST(n.apgar_5min AS DECIMAL(4,2))) AS DECIMAL(4,2))  AS apgar5_medio,
        MIN(n.peso_g) AS menor_peso_g,
        MAX(n.peso_g) AS maior_peso_g
FROM clinico.nascimento n
JOIN cadastro.crianca c ON c.crianca_id  = n.crianca_id
JOIN clinico.parto   pa ON pa.gestacao_id = c.gestacao_id
GROUP BY pa.tipo_parto;
GO

/* Q9 — Cobertura das triagens neonatais (% realizadas por teste) */
SELECT  nome_popular,
        COUNT(*)                                                   AS criancas,
        SUM(CASE WHEN situacao = 'REALIZADA' THEN 1 ELSE 0 END)    AS realizadas,
        SUM(CASE WHEN situacao = 'ATRASADA'  THEN 1 ELSE 0 END)    AS atrasadas,
        CAST(100.0 * SUM(CASE WHEN situacao = 'REALIZADA' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS cobertura_pct,
        SUM(CASE WHEN resultado = 'ALTERADO' THEN 1 ELSE 0 END)    AS alterados
FROM clinico.vw_triagem_situacao
GROUP BY tipo_triagem_id, nome_popular
ORDER BY tipo_triagem_id;
GO

/* Q10 — Aleitamento materno exclusivo na consulta da 1ª semana, por unidade */
SELECT  u.nome AS unidade,
        COUNT(*) AS consultas_1a_semana,
        SUM(CASE WHEN co.aleitamento = 'LME' THEN 1 ELSE 0 END) AS em_lme,
        CAST(100.0 * SUM(CASE WHEN co.aleitamento = 'LME' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS lme_pct
FROM atendimento.consulta co
JOIN cadastro.unidade_saude u ON u.unidade_id = co.unidade_id
WHERE co.tipo_atendimento = 'PRIMEIRA_SEMANA'
GROUP BY u.nome;
GO

/* Q11 — Produção por profissional nos últimos 30 dias,
   só quem teve 2 ou mais atendimentos (HAVING filtra DEPOIS do GROUP BY) */
SELECT  p.nome AS profissional,
        cat.nome AS categoria,
        COUNT(*) AS atendimentos,
        MIN(co.data_consulta) AS primeiro,
        MAX(co.data_consulta) AS ultimo
FROM atendimento.consulta co
JOIN cadastro.profissional p          ON p.profissional_id = co.profissional_id
JOIN dominio.categoria_profissional cat ON cat.categoria_id = p.categoria_id
WHERE co.data_consulta >= DATEADD(DAY, -30, GETDATE())
GROUP BY p.nome, cat.nome
HAVING COUNT(*) >= 2
ORDER BY atendimentos DESC;
GO

/* Q12 — Crianças que merecem cuidado especial, por unidade e motivo */
SELECT  unidade_nome,
        COUNT(*)                     AS criancas_ativas,
        SUM(CAST(cuidado_especial AS INT))  AS cuidado_especial,
        SUM(alerta_baixo_peso)       AS baixo_peso,
        SUM(alerta_prematuro)        AS prematuros,
        SUM(alerta_apgar_baixo)      AS apgar_baixo,
        SUM(alerta_mae_adolescente)  AS mae_adolescente,
        SUM(alerta_utin)             AS passou_utin
FROM cadastro.vw_crianca_resumo
WHERE ativo = 1
GROUP BY unidade_nome;
GO

/* Q13 — Sorologias ALTERADAS no pré-natal (vigilância de transmissão vertical) */
SELECT  ge.nome AS gestante,
        a.cid10, a.nome AS agravo,
        s.trimestre,
        STRING_AGG(c.nome, N', ') AS filhos
FROM clinico.sorologia_prenatal s
JOIN dominio.agravo     a  ON a.agravo_id    = s.agravo_id
JOIN clinico.gestacao   g  ON g.gestacao_id  = s.gestacao_id
JOIN cadastro.gestante  ge ON ge.gestante_id = g.gestante_id
LEFT JOIN cadastro.crianca c ON c.gestacao_id = g.gestacao_id
WHERE s.resultado = 'ALT'
GROUP BY ge.nome, a.cid10, a.nome, s.trimestre;
GO
