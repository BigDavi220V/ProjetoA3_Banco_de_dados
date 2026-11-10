/* =====================================================================
   01_consultas_operacionais.sql  —  DQL: consultas do dia a dia
   ---------------------------------------------------------------------
   Cada consulta tem: PERGUNTA de negócio -> SQL -> o que observar.
   As mesmas consultas são usadas pela aplicação (backend/src/repositories).
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* Q1 — "Quem eu atendo hoje?"  (INNER JOIN em 6 tabelas)
   A recepção abre o dia com esta lista. */
SELECT  CONVERT(CHAR(5), a.data_hora, 108)          AS hora,
        c.nome                                      AS crianca,
        DATEDIFF(DAY, c.data_nascimento, a.data_hora) AS dias_de_vida,
        ge.nome                                     AS mae,
        a.tipo_atendimento,
        p.nome                                      AS profissional,
        e.nome                                      AS especialidade,
        u.nome                                      AS unidade,
        a.status
FROM atendimento.agendamento a
INNER JOIN cadastro.crianca       c  ON c.crianca_id       = a.crianca_id
INNER JOIN clinico.gestacao       g  ON g.gestacao_id      = c.gestacao_id
INNER JOIN cadastro.gestante      ge ON ge.gestante_id     = g.gestante_id
INNER JOIN cadastro.profissional  p  ON p.profissional_id  = a.profissional_id
INNER JOIN dominio.especialidade  e  ON e.especialidade_id = a.especialidade_id
INNER JOIN cadastro.unidade_saude u  ON u.unidade_id       = a.unidade_id
WHERE CAST(a.data_hora AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY a.data_hora;
GO

/* Q2 — Busca de criança pelo nome DELA ou da MÃE (a recepção quase
   sempre lembra o nome da mãe). LIKE + collation sem acento. */
DECLARE @busca NVARCHAR(100) = N'lopes';

SELECT  c.crianca_id, c.nome, c.data_nascimento,
        DATEDIFF(DAY, c.data_nascimento, GETDATE()) AS dias_de_vida,
        ge.nome AS mae, pr.numero AS prontuario
FROM cadastro.crianca c
JOIN clinico.gestacao g   ON g.gestacao_id  = c.gestacao_id
JOIN cadastro.gestante ge ON ge.gestante_id = g.gestante_id
LEFT JOIN clinico.prontuario pr ON pr.crianca_id = c.crianca_id
WHERE c.ativo = 1
  AND (c.nome LIKE N'%' + @busca + N'%' OR ge.nome LIKE N'%' + @busca + N'%')
ORDER BY c.data_nascimento DESC;
GO

/* Q3 — "Quais MÉDICOS atendem Pediatria?" (filtro de profissionais,
   requisito "Consulta (Read)" do edital). N:N via tabela associativa. */
DECLARE @especialidade NVARCHAR(80) = N'Pediatria';

SELECT  p.nome, cat.nome AS categoria,
        CONCAT(cat.conselho, ' ', p.registro_conselho, '/', p.uf_conselho) AS registro,
        u.nome AS lotacao
FROM cadastro.profissional p
JOIN dominio.categoria_profissional  cat ON cat.categoria_id     = p.categoria_id
JOIN cadastro.profissional_especialidade pe ON pe.profissional_id = p.profissional_id
JOIN dominio.especialidade           e   ON e.especialidade_id   = pe.especialidade_id
JOIN cadastro.unidade_saude          u   ON u.unidade_id         = p.unidade_id
WHERE e.nome = @especialidade
  AND cat.conselho = 'CRM'
  AND p.ativo = 1
ORDER BY p.nome;
GO

/* Q4 — Prontuário: linha do tempo completa de uma criança (VIEW com UNION ALL) */
DECLARE @crianca INT = 4;

SELECT data_evento, tipo_evento, titulo, detalhe, profissional_nome
FROM clinico.vw_linha_tempo_crianca
WHERE crianca_id = @crianca
ORDER BY data_evento;
GO

/* Q5 — Triagens neonatais pendentes ou atrasadas (busca ativa) */
SELECT  crianca_nome,
        DATEDIFF(DAY, data_nascimento, GETDATE()) AS dias_de_vida,
        CONCAT(N'Teste ', nome_popular)           AS triagem,
        situacao,
        prazo_max_dias
FROM clinico.vw_triagem_situacao
WHERE situacao IN ('PENDENTE','ATRASADA','NAO_REALIZADA')
   OR resultado IN ('ALTERADO','REPETIR')
ORDER BY CASE situacao WHEN 'ATRASADA' THEN 1 WHEN 'NAO_REALIZADA' THEN 2 ELSE 3 END,
         data_nascimento;
GO

/* Q6 — Recém-nascidos (até 10 dias) SEM consulta da 1ª semana registrada.
   LEFT JOIN + IS NULL = "quem está na tabela da esquerda e NÃO tem par". */
SELECT  c.nome,
        DATEDIFF(DAY, c.data_nascimento, GETDATE()) AS dias_de_vida,
        u.nome AS unidade,
        CASE WHEN ag.agendamento_id IS NULL THEN N'Sem agendamento' ELSE N'Agendada' END AS situacao
FROM cadastro.crianca c
JOIN cadastro.unidade_saude u ON u.unidade_id = c.unidade_referencia_id
LEFT JOIN atendimento.consulta co
       ON co.crianca_id = c.crianca_id AND co.tipo_atendimento = 'PRIMEIRA_SEMANA'
LEFT JOIN atendimento.agendamento ag
       ON ag.crianca_id = c.crianca_id AND ag.tipo_atendimento = 'PRIMEIRA_SEMANA' AND ag.status = 'AGENDADO'
WHERE c.ativo = 1
  AND co.consulta_id IS NULL
  AND DATEDIFF(DAY, c.data_nascimento, GETDATE()) <= 10
ORDER BY dias_de_vida DESC;
GO
