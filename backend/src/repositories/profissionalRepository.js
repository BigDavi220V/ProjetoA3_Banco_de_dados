/**
 * repositories/profissionalRepository.js — "Filtro e exibição de médicos"
 * Filtros opcionais com o padrão (@param IS NULL OR coluna = @param):
 * se o filtro não veio, a condição vira verdadeira e não restringe nada.
 */
const { query } = require('../config/db');

async function listar({ especialidadeId, categoriaId, unidadeId, busca } = {}) {
  return query(`
    SELECT p.profissional_id,
           p.nome,
           cat.nome     AS categoria,
           cat.conselho,
           p.registro_conselho,
           p.uf_conselho,
           p.unidade_id,
           u.nome       AS unidade,
           STRING_AGG(e.nome, N', ') WITHIN GROUP (ORDER BY e.nome)               AS especialidades,
           STRING_AGG(CAST(e.especialidade_id AS VARCHAR(10)), ',')                AS especialidade_ids,
           (SELECT COUNT(*) FROM atendimento.consulta co
             WHERE co.profissional_id = p.profissional_id
               AND co.data_consulta >= DATEADD(DAY, -30, SYSDATETIME()))           AS consultas_30_dias,
           (SELECT COUNT(*) FROM atendimento.agendamento a
             WHERE a.profissional_id = p.profissional_id
               AND a.status = 'AGENDADO' AND a.data_hora >= SYSDATETIME())         AS agendamentos_futuros
    FROM cadastro.profissional p
    JOIN dominio.categoria_profissional cat ON cat.categoria_id = p.categoria_id
    JOIN cadastro.unidade_saude u           ON u.unidade_id     = p.unidade_id
    LEFT JOIN cadastro.profissional_especialidade pe ON pe.profissional_id = p.profissional_id
    LEFT JOIN dominio.especialidade e                ON e.especialidade_id = pe.especialidade_id
    WHERE p.ativo = 1
      AND (@categoria_id IS NULL OR p.categoria_id = @categoria_id)
      AND (@unidade_id   IS NULL OR p.unidade_id   = @unidade_id)
      AND (@busca        IS NULL OR p.nome LIKE N'%' + @busca + N'%')
      AND (@especialidade_id IS NULL OR EXISTS (
            SELECT 1 FROM cadastro.profissional_especialidade x
            WHERE x.profissional_id = p.profissional_id AND x.especialidade_id = @especialidade_id))
    GROUP BY p.profissional_id, p.nome, cat.nome, cat.conselho, p.registro_conselho,
             p.uf_conselho, p.unidade_id, u.nome
    ORDER BY p.nome;`,
  {
    especialidade_id: especialidadeId || null,
    categoria_id:     categoriaId || null,
    unidade_id:       unidadeId || null,
    busca:            busca ? String(busca).trim() : null,
  });
}

module.exports = { listar };
