// controllers/authController.js — recebe a requisição HTTP e chama o service
const authService = require('../services/authService');

async function login(req, res, next) {
  try {
    res.json(await authService.login(req.body.login, req.body.senha));
  } catch (err) { next(err); }
}

async function eu(req, res, next) {
  try {
    res.json(await authService.eu(req.usuario));
  } catch (err) { next(err); }
}

module.exports = { login, eu };
