/**
 * config/permissoes.js — O que cada perfil pode fazer na API
 *
 * O banco também protege (usuário app_caderneta com GRANTs restritos),
 * mas a regra "recepção não registra consulta" é de NEGÓCIO e fica aqui.
 */
const MATRIZ = {
  RECEPCAO: [
    'dashboard.ver', 'criancas.ver', 'criancas.editar', 'gestantes.editar',
    'caderneta.ver', 'agenda.ver', 'agenda.gerenciar', 'profissionais.ver',
  ],
  ENFERMAGEM: [
    'dashboard.ver', 'criancas.ver', 'criancas.editar', 'gestantes.editar',
    'caderneta.ver', 'caderneta.editar', 'consulta.registrar', 'vacina.registrar',
    'agenda.ver', 'profissionais.ver',
  ],
  MEDICO: [
    'dashboard.ver', 'criancas.ver', 'caderneta.ver', 'caderneta.editar',
    'consulta.registrar', 'vacina.registrar', 'agenda.ver', 'profissionais.ver',
  ],
  GESTOR: [
    'dashboard.ver', 'criancas.ver', 'criancas.editar', 'criancas.excluir',
    'caderneta.ver', 'agenda.ver', 'agenda.gerenciar', 'agenda.excluir',
    'profissionais.ver', 'relatorios.ver', 'auditoria.ver',
  ],
};

function permissoesDoPerfil(perfil) {
  return MATRIZ[perfil] || [];
}

function pode(perfil, permissao) {
  return permissoesDoPerfil(perfil).includes(permissao);
}

module.exports = { MATRIZ, permissoesDoPerfil, pode };
