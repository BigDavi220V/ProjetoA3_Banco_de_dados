/**
 * repositories/relatorioRepository.js — Relatórios gerenciais (DQL)
 *
 * Cada relatório guarda o SQL que executa. A tela mostra o SQL ao lado
 * do resultado ("Ver SQL"), para a banca ver a ligação aplicação <-> banco.
 * Os mesmos comandos estão comentados em database/04_dql/.
 */
const { query } = require('../config/db');

const RELATORIOS = [
  {
    codigo: 'por-especialidade',
    titulo: 'Atendimentos por especialidade',
    pergunta: 'Quantas consultas cada especialidade fez no período?',
    arquivo: '04_dql/02_consultas_gerenciais.sql (Q7)',
    usaPeriodo: true,
    sql: `SELECT  e.nome                         AS especialidade,
        COUNT(co.consulta_id)          AS total_consultas,
        COUNT(DISTINCT co.crianca_id)  AS criancas_atendidas,
        SUM(CASE WHEN co.local_atendimento = 'DOMICILIO' THEN 1 ELSE 0 END) AS em_domicilio
FROM dominio.especialidade e
LEFT JOIN atendimento.consulta co
       ON co.especialidade_id = e.especialidade_id
      AND co.data_consulta >= @inicio
      AND co.data_consulta <  DATEADD(DAY, 1, @fim)
GROUP BY e.nome
ORDER BY total_consultas DESC, e.nome;`,
  },
  {
    codigo: 'cobertura-triagens',
    titulo: 'Cobertura das triagens neonatais',
    pergunta: 'Qual o percentual de crianças com cada teste realizado?',
    arquivo: '04_dql/02_consultas_gerenciais.sql (Q9)',
    usaPeriodo: false,
    sql: `SELECT  nome_popular                                               AS teste,
        COUNT(*)                                                   AS criancas,
        SUM(CASE WHEN situacao = 'REALIZADA' THEN 1 ELSE 0 END)    AS realizadas,
        SUM(CASE WHEN situacao = 'PENDENTE'  THEN 1 ELSE 0 END)    AS pendentes,
        SUM(CASE WHEN situacao = 'ATRASADA'  THEN 1 ELSE 0 END)    AS atrasadas,
        CAST(100.0 * SUM(CASE WHEN situacao = 'REALIZADA' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS cobertura_pct,
        SUM(CASE WHEN resultado = 'ALTERADO' THEN 1 ELSE 0 END)    AS alterados
FROM clinico.vw_triagem_situacao
GROUP BY tipo_triagem_id, nome_popular
ORDER BY tipo_triagem_id;`,
  },
  {
    codigo: 'peso-por-parto',
    titulo: 'Peso ao nascer por tipo de parto',
    pergunta: 'Qual o peso médio e o Apgar médio em partos vaginais e cesáreas?',
    arquivo: '04_dql/02_consultas_gerenciais.sql (Q8)',
    usaPeriodo: true,
    sql: `SELECT  pa.tipo_parto,
        COUNT(*)                                                       AS nascimentos,
        CAST(AVG(CAST(n.peso_g AS DECIMAL(7,1))) AS DECIMAL(7,1))      AS peso_medio_g,
        CAST(AVG(CAST(n.apgar_5min AS DECIMAL(4,2))) AS DECIMAL(4,2))  AS apgar5_medio,
        MIN(n.peso_g)                                                  AS menor_peso_g,
        MAX(n.peso_g)                                                  AS maior_peso_g
FROM clinico.nascimento n
JOIN cadastro.crianca c ON c.crianca_id   = n.crianca_id
JOIN clinico.parto   pa ON pa.gestacao_id = c.gestacao_id
WHERE pa.data_parto BETWEEN @inicio AND @fim
GROUP BY pa.tipo_parto;`,
  },
  {
    codigo: 'aleitamento',
    titulo: 'Aleitamento exclusivo na 1ª semana',
    pergunta: 'Que percentual dos bebês estava em leite materno exclusivo na consulta da 1ª semana?',
    arquivo: '04_dql/02_consultas_gerenciais.sql (Q10)',
    usaPeriodo: true,
    sql: `SELECT  u.nome                                                   AS unidade,
        COUNT(*)                                                 AS consultas_1a_semana,
        SUM(CASE WHEN co.aleitamento = 'LME' THEN 1 ELSE 0 END)  AS em_lme,
        CAST(100.0 * SUM(CASE WHEN co.aleitamento = 'LME' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS lme_pct
FROM atendimento.consulta co
JOIN cadastro.unidade_saude u ON u.unidade_id = co.unidade_id
WHERE co.tipo_atendimento = 'PRIMEIRA_SEMANA'
  AND co.data_consulta >= @inicio AND co.data_consulta < DATEADD(DAY, 1, @fim)
GROUP BY u.nome;`,
  },
  {
    codigo: 'cuidado-especial',
    titulo: 'Crianças que merecem cuidado especial',
    pergunta: 'Quantas crianças de risco cada unidade acompanha, e por quê?',
    arquivo: '04_dql/02_consultas_gerenciais.sql (Q12)',
    usaPeriodo: false,
    sql: `SELECT  unidade_nome                         AS unidade,
        COUNT(*)                             AS criancas_ativas,
        SUM(CAST(cuidado_especial AS INT))   AS cuidado_especial,
        SUM(alerta_baixo_peso)               AS baixo_peso,
        SUM(alerta_prematuro)                AS prematuros,
        SUM(alerta_apgar_baixo)              AS apgar_baixo,
        SUM(alerta_mae_adolescente)          AS mae_adolescente,
        SUM(alerta_utin)                     AS passou_utin
FROM cadastro.vw_crianca_resumo
WHERE ativo = 1
GROUP BY unidade_nome;`,
  },
  {
    codigo: 'ganho-peso',
    titulo: 'Ganho de peso desde o nascimento',
    pergunta: 'Quanto cada criança ganhou por dia até a última consulta? (CTE + ROW_NUMBER)',
    arquivo: '04_dql/03_consultas_avancadas.sql (Q14)',
    usaPeriodo: false,
    sql: `WITH ultima_consulta AS (
    SELECT co.crianca_id, co.data_consulta, co.peso_g,
           ROW_NUMBER() OVER (PARTITION BY co.crianca_id ORDER BY co.data_consulta DESC) AS ordem
    FROM atendimento.consulta co
    WHERE co.peso_g IS NOT NULL
)
SELECT  c.nome                                             AS crianca,
        n.peso_g                                           AS peso_nascer_g,
        u.peso_g                                           AS peso_atual_g,
        DATEDIFF(DAY, c.data_nascimento, u.data_consulta)  AS dias,
        CAST(1.0 * (u.peso_g - n.peso_g)
             / NULLIF(DATEDIFF(DAY, c.data_nascimento, u.data_consulta), 0) AS DECIMAL(6,1)) AS ganho_g_dia
FROM ultima_consulta u
JOIN cadastro.crianca   c ON c.crianca_id = u.crianca_id
JOIN clinico.nascimento n ON n.crianca_id = u.crianca_id
WHERE u.ordem = 1
ORDER BY ganho_g_dia;`,
  },
  {
    codigo: 'absenteismo',
    titulo: 'Absenteísmo por unidade',
    pergunta: 'Que percentual dos agendamentos vencidos terminou em falta?',
    arquivo: '04_dql/03_consultas_avancadas.sql (Q17)',
    usaPeriodo: true,
    sql: `SELECT  u.nome                                                  AS unidade,
        COUNT(*)                                                AS agendamentos_passados,
        SUM(CASE WHEN a.status = 'FALTOU' THEN 1 ELSE 0 END)    AS faltas,
        CAST(100.0 * SUM(CASE WHEN a.status = 'FALTOU' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS absenteismo_pct
FROM atendimento.agendamento a
JOIN cadastro.unidade_saude u ON u.unidade_id = a.unidade_id
WHERE a.data_hora >= @inicio
  AND a.data_hora <  CAST(GETDATE() AS DATE)
  AND a.data_hora <  DATEADD(DAY, 1, @fim)
  AND a.status <> 'CANCELADO'
GROUP BY u.nome;`,
  },
  {
    codigo: 'sorologias-alteradas',
    titulo: 'Sorologias alteradas no pré-natal',
    pergunta: 'Quais gestantes tiveram sorologia alterada, e quem são os filhos? (STRING_AGG)',
    arquivo: '04_dql/02_consultas_gerenciais.sql (Q13)',
    usaPeriodo: false,
    sql: `SELECT  ge.nome                        AS gestante,
        a.cid10,
        a.nome                         AS agravo,
        s.trimestre,
        STRING_AGG(c.nome, N', ')      AS filhos
FROM clinico.sorologia_prenatal s
JOIN dominio.agravo     a  ON a.agravo_id    = s.agravo_id
JOIN clinico.gestacao   g  ON g.gestacao_id  = s.gestacao_id
JOIN cadastro.gestante  ge ON ge.gestante_id = g.gestante_id
LEFT JOIN cadastro.crianca c ON c.gestacao_id = g.gestacao_id
WHERE s.resultado = 'ALT'
GROUP BY ge.nome, a.cid10, a.nome, s.trimestre;`,
  },
];

function catalogo() {
  return RELATORIOS.map(({ codigo, titulo, pergunta, arquivo, usaPeriodo, sql }) =>
    ({ codigo, titulo, pergunta, arquivo, usaPeriodo, sql }));
}

async function executar(codigo, { inicio, fim }) {
  const rel = RELATORIOS.find(r => r.codigo === codigo);
  if (!rel) return null;
  const linhas = await query(rel.sql, { inicio, fim });
  return { ...rel, linhas };
}

async function auditoria({ tabela, limite = 50 } = {}) {
  return query(`
    SELECT TOP (@limite)
           l.log_id, l.data_hora, l.tabela, l.operacao, l.chave,
           ISNULL(u.nome_exibicao, N'(script / sistema)') AS usuario,
           l.dados_antes, l.dados_depois
    FROM auditoria.log_auditoria l
    LEFT JOIN seguranca.usuario u ON u.usuario_id = l.usuario_id
    WHERE (@tabela IS NULL OR l.tabela = @tabela)
    ORDER BY l.log_id DESC;`, { tabela: tabela || null, limite: Math.min(parseInt(limite, 10) || 50, 200) });
}

module.exports = { catalogo, executar, auditoria };
