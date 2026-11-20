/**
 * repositories/gestanteRepository.js — Mães / gestantes e telefones
 */
const { query } = require('../config/db');

async function buscar(busca) {
  return query(`
    SELECT TOP (20)
           g.gestante_id, g.nome, g.cpf, g.cns, g.data_nascimento, g.bairro,
           DATEDIFF(YEAR, g.data_nascimento, GETDATE()) AS idade_aprox,
           (SELECT STRING_AGG(CONCAT(N'(', t.ddd, N') ', t.numero), N' · ')
              FROM cadastro.gestante_telefone t WHERE t.gestante_id = g.gestante_id) AS telefones,
           (SELECT COUNT(*) FROM cadastro.crianca c
              JOIN clinico.gestacao gs ON gs.gestacao_id = c.gestacao_id
             WHERE gs.gestante_id = g.gestante_id) AS filhos
    FROM cadastro.gestante g
    WHERE @busca IS NULL
       OR g.nome LIKE N'%' + @busca + N'%'
       OR g.cpf = @busca
       OR g.cns = @busca
    ORDER BY g.nome;`, { busca: busca ? String(busca).trim() : null });
}

/** INSERT ... OUTPUT INSERTED.<id> devolve o ID gerado pelo IDENTITY */
async function inserir(g, tx) {
  const [linha] = await query(`
    INSERT INTO cadastro.gestante
        (nome, cpf, cns, data_nascimento, tipo_sanguineo, fator_rh,
         logradouro, numero, bairro, cep, unidade_referencia_id)
    OUTPUT INSERTED.gestante_id
    VALUES (@nome, @cpf, @cns, @data_nascimento, @tipo_sanguineo, @fator_rh,
            @logradouro, @numero, @bairro, @cep, @unidade_referencia_id);`,
  {
    nome: g.nome, cpf: g.cpf, cns: g.cns, data_nascimento: g.data_nascimento,
    tipo_sanguineo: g.tipo_sanguineo, fator_rh: g.fator_rh,
    logradouro: g.logradouro, numero: g.numero, bairro: g.bairro, cep: g.cep,
    unidade_referencia_id: g.unidade_referencia_id,
  }, tx);
  return linha.gestante_id;
}

async function inserirTelefone(gestanteId, t, tx) {
  await query(`
    INSERT INTO cadastro.gestante_telefone (gestante_id, ddd, numero, tipo, whatsapp)
    VALUES (@gestante_id, @ddd, @numero, @tipo, @whatsapp);`,
  { gestante_id: gestanteId, ddd: t.ddd, numero: t.numero, tipo: t.tipo || 'CELULAR', whatsapp: !!t.whatsapp }, tx);
}

module.exports = { buscar, inserir, inserirTelefone };
