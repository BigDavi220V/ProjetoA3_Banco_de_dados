/**
 * services/authService.js — Login com bcrypt + JWT
 */
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const repo = require('../repositories/authRepository');
const { permissoesDoPerfil } = require('../config/permissoes');
const { JWT_SECRET } = require('../middlewares/auth');
const { ErroNegocio } = require('../utils/validacao');

async function login(login, senha) {
  if (!login || !senha) throw new ErroNegocio('Informe usuário e senha.', 400);

  const usuario = await repo.buscarPorLogin(String(login).trim().toLowerCase());
  // Mesma mensagem para usuário inexistente e senha errada (não revela qual dos dois)
  if (!usuario || !usuario.ativo || !(await bcrypt.compare(senha, usuario.senha_hash))) {
    throw new ErroNegocio('Usuário ou senha incorretos.', 401);
  }

  await repo.registrarAcesso(usuario.usuario_id);

  const payload = {
    usuario_id:      usuario.usuario_id,
    nome:            usuario.nome_exibicao,
    perfil:          usuario.perfil,
    profissional_id: usuario.profissional_id,
    unidade_id:      usuario.unidade_id,
  };
  const token = jwt.sign(payload, JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '8h' });
  return { token, usuario: await perfilCompleto(payload, usuario) };
}

async function perfilCompleto(payload, extra = {}) {
  return {
    ...payload,
    perfil_nome:   extra.perfil_nome,
    categoria:     extra.categoria_nome,
    permissoes:    permissoesDoPerfil(payload.perfil),
    especialidades: await repo.especialidadesDoProfissional(payload.profissional_id),
  };
}

/** GET /auth/me — devolve o usuário do token com permissões e especialidades */
async function eu(tokenPayload) {
  return perfilCompleto(tokenPayload);
}

module.exports = { login, eu };
