/**
 * repositories/authRepository.js — SQL de login
 * Camada REPOSITORY: o único lugar do backend que escreve SQL.
 */
const { query } = require('../config/db');

async function buscarPorLogin(login) {
  const linhas = await query(`
    SELECT u.usuario_id, u.login, u.senha_hash, u.nome_exibicao, u.ativo,
           u.profissional_id, p.codigo AS perfil, p.nome AS perfil_nome,
           pr.unidade_id, pr.nome AS profissional_nome,
           cat.nome AS categoria_nome
    FROM seguranca.usuario u
    JOIN seguranca.perfil p                    ON p.perfil_id = u.perfil_id
    LEFT JOIN cadastro.profissional pr         ON pr.profissional_id = u.profissional_id
    LEFT JOIN dominio.categoria_profissional cat ON cat.categoria_id = pr.categoria_id
    WHERE u.login = @login;`, { login });
  return linhas[0] || null;
}

async function registrarAcesso(usuarioId) {
  await query(`UPDATE seguranca.usuario SET ultimo_acesso = SYSDATETIME() WHERE usuario_id = @id;`, { id: usuarioId });
}

/** Especialidades do profissional logado (para pré-selecionar na consulta) */
async function especialidadesDoProfissional(profissionalId) {
  if (!profissionalId) return [];
  return query(`
    SELECT e.especialidade_id, e.nome
    FROM cadastro.profissional_especialidade pe
    JOIN dominio.especialidade e ON e.especialidade_id = pe.especialidade_id
    WHERE pe.profissional_id = @id
    ORDER BY e.nome;`, { id: profissionalId });
}

module.exports = { buscarPorLogin, registrarAcesso, especialidadesDoProfissional };
