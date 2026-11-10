/**
 * middlewares/auth.js — Autenticação (JWT) e autorização (perfil)
 */
const jwt = require('jsonwebtoken');
const { pode } = require('../config/permissoes');

const JWT_SECRET = process.env.JWT_SECRET || 'troque_este_segredo_no_env';

/** Exige header "Authorization: Bearer <token>" e preenche req.usuario */
function autenticar(req, res, next) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) {
    return res.status(401).json({ erro: 'Faça login para continuar.' });
  }
  try {
    req.usuario = jwt.verify(header.slice(7), JWT_SECRET);
    next();
  } catch (err) {
    const msg = err.name === 'TokenExpiredError' ? 'Sua sessão expirou. Entre novamente.' : 'Sessão inválida.';
    return res.status(401).json({ erro: msg });
  }
}

/** Uso: router.post('/rota', autenticar, exigir('agenda.gerenciar'), controller) */
function exigir(...permissoes) {
  return (req, res, next) => {
    if (permissoes.some(p => pode(req.usuario?.perfil, p))) return next();
    return res.status(403).json({ erro: 'Seu perfil não tem permissão para esta ação.' });
  };
}

module.exports = { autenticar, exigir, JWT_SECRET };
