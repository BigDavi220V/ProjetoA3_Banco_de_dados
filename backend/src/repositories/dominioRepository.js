/**
 * repositories/dominioRepository.js — Listas de opções dos formulários
 * Um único comando com vários SELECTs = uma ida ao banco só.
 */
const { query, queryMultiplo } = require('../config/db');

async function listarTudo() {
  const [especialidades, categorias, agravos, vacinas, tiposTriagem, sinais, setores, unidades] = await queryMultiplo(`
    SELECT especialidade_id, nome FROM dominio.especialidade ORDER BY nome;
    SELECT categoria_id, nome, conselho FROM dominio.categoria_profissional ORDER BY nome;
    SELECT agravo_id, cid10, nome FROM dominio.agravo ORDER BY agravo_id;
    SELECT vacina_id, sigla, nome, publico_alvo FROM dominio.vacina ORDER BY vacina_id;
    SELECT tipo_triagem_id, codigo, nome, nome_popular, orientacao_prazo, prazo_max_dias, avalia_lateralidade
      FROM dominio.tipo_triagem ORDER BY tipo_triagem_id;
    SELECT sinal_alerta_id, nome, criterio FROM dominio.sinal_alerta ORDER BY ordem_exibicao;
    SELECT setor_id, sigla, nome FROM dominio.setor_internacao ORDER BY setor_id;
    SELECT unidade_id, nome, tipo FROM cadastro.unidade_saude WHERE ativo = 1 ORDER BY nome;`);
  return { especialidades, categorias, agravos, vacinas, tiposTriagem, sinais, setores, unidades };
}

async function listarUnidades() {
  return query(`SELECT unidade_id, cnes, nome, tipo, bairro, municipio FROM cadastro.unidade_saude WHERE ativo = 1 ORDER BY nome;`);
}

module.exports = { listarTudo, listarUnidades };
