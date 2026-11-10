/**
 * repositories/criancaRepository.js — Cadastro da criança
 *
 * Atenção (regra do SQL Server): tabelas com TRIGGER não aceitam
 * "INSERT ... OUTPUT INSERTED.id" sem INTO. Por isso aqui usamos
 * SCOPE_IDENTITY(), que devolve o último ID gerado NESTE escopo
 * (ignora os IDs gerados dentro do trigger, como o do prontuário).
 * Para contar linhas afetadas usamos OUTPUT ... INTO @tabela, que é
 * permitido mesmo com trigger e não depende de @@ROWCOUNT.
 */
const { query } = require('../config/db');

async function listar({ busca, situacao = 'ativas', cuidado, unidadeId } = {}) {
  return query(`
    SELECT r.crianca_id, r.nome, r.sexo, r.data_nascimento, r.idade_dias, r.cns, r.ativo,
           r.prontuario_numero, r.mae_nome, r.unidade_id, r.unidade_nome,
           r.peso_nascer_g, r.ig_semanas, r.adequacao_peso_ig, r.cuidado_especial,
           (SELECT COUNT(*) FROM clinico.vw_triagem_situacao t
             WHERE t.crianca_id = r.crianca_id AND t.situacao IN ('PENDENTE','ATRASADA')) AS triagens_pendentes,
           (SELECT MIN(a.data_hora) FROM atendimento.agendamento a
             WHERE a.crianca_id = r.crianca_id AND a.status = 'AGENDADO'
               AND a.data_hora >= CAST(GETDATE() AS DATE))                             AS proximo_agendamento
    FROM cadastro.vw_crianca_resumo r
    WHERE (@situacao = 'todas'
           OR (@situacao = 'ativas'   AND r.ativo = 1)
           OR (@situacao = 'inativas' AND r.ativo = 0))
      AND (@cuidado    IS NULL OR r.cuidado_especial = @cuidado)
      AND (@unidade_id IS NULL OR r.unidade_id = @unidade_id)
      AND (@busca IS NULL
           OR r.nome     LIKE N'%' + @busca + N'%'
           OR r.mae_nome LIKE N'%' + @busca + N'%'
           OR r.cns = @busca
           OR r.prontuario_numero = @busca)
    ORDER BY r.ativo DESC, r.data_nascimento DESC;`,
  {
    busca:      busca ? String(busca).trim() : null,
    situacao,
    cuidado:    cuidado === undefined || cuidado === '' ? null : (cuidado === '1' || cuidado === true),
    unidade_id: unidadeId || null,
  });
}

async function buscarResumo(criancaId) {
  const [linha] = await query(`SELECT * FROM cadastro.vw_crianca_resumo WHERE crianca_id = @id;`, { id: criancaId });
  return linha || null;
}

/** Gestação nova para a mãe (cada filho "não gêmeo" abre uma gestação) */
async function criarGestacao(gestanteId, tx) {
  const [linha] = await query(`
    INSERT INTO clinico.gestacao (gestante_id) OUTPUT INSERTED.gestacao_id VALUES (@gestante_id);`,
  { gestante_id: gestanteId }, tx);
  return linha.gestacao_id;
}

async function gestacaoDaCrianca(criancaId, tx) {
  const [linha] = await query(`
    SELECT c.gestacao_id, g.gestante_id, g.tipo_gravidez
    FROM cadastro.crianca c JOIN clinico.gestacao g ON g.gestacao_id = c.gestacao_id
    WHERE c.crianca_id = @id;`, { id: criancaId }, tx);
  return linha || null;
}

async function marcarGemelar(gestacaoId, tx) {
  await query(`UPDATE clinico.gestacao SET tipo_gravidez = 'MULTIPLA' WHERE gestacao_id = @id;`, { id: gestacaoId }, tx);
}

async function inserir(c, tx) {
  const [linha] = await query(`
    INSERT INTO cadastro.crianca
        (gestacao_id, nome, sexo, data_nascimento, cns, tipo_sanguineo, fator_rh, unidade_referencia_id)
    VALUES (@gestacao_id, @nome, @sexo, @data_nascimento, @cns, @tipo_sanguineo, @fator_rh, @unidade_referencia_id);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS crianca_id;`,
  {
    gestacao_id: c.gestacao_id, nome: c.nome, sexo: c.sexo, data_nascimento: c.data_nascimento,
    cns: c.cns, tipo_sanguineo: c.tipo_sanguineo, fator_rh: c.fator_rh,
    unidade_referencia_id: c.unidade_referencia_id,
  }, tx);
  return linha.crianca_id;
}

async function atualizar(id, c, tx) {
  const linhas = await query(`
    DECLARE @alteradas TABLE (crianca_id INT);
    UPDATE cadastro.crianca
       SET nome = @nome, sexo = @sexo, data_nascimento = @data_nascimento, cns = @cns,
           tipo_sanguineo = @tipo_sanguineo, fator_rh = @fator_rh,
           unidade_referencia_id = @unidade_referencia_id
    OUTPUT INSERTED.crianca_id INTO @alteradas
     WHERE crianca_id = @id;
    SELECT COUNT(*) AS afetadas FROM @alteradas;`,
  {
    id, nome: c.nome, sexo: c.sexo, data_nascimento: c.data_nascimento, cns: c.cns,
    tipo_sanguineo: c.tipo_sanguineo, fator_rh: c.fator_rh, unidade_referencia_id: c.unidade_referencia_id,
  }, tx);
  return linhas[0].afetadas;
}

/** Exclusão LÓGICA: procedure inativa e cancela os agendamentos futuros */
async function inativar(id, motivo, tx) {
  await query(`EXEC cadastro.sp_inativar_crianca @crianca_id = @id, @motivo = @motivo;`, { id, motivo }, tx);
}

async function reativar(id, tx) {
  await query(`
    UPDATE cadastro.crianca
       SET ativo = 1, inativado_em = NULL, motivo_inativacao = NULL
     WHERE crianca_id = @id AND ativo = 0;`, { id }, tx);
}

/** Exclusão FÍSICA (só gestor). Tabelas filhas com ON DELETE CASCADE vão junto;
    se houver agenda/consulta, a FK bloqueia e o errorHandler explica. */
async function excluirFisico(id, tx) {
  const [linha] = await query(`
    DECLARE @apagadas TABLE (crianca_id INT);
    DELETE FROM cadastro.crianca OUTPUT DELETED.crianca_id INTO @apagadas WHERE crianca_id = @id;
    SELECT COUNT(*) AS afetadas FROM @apagadas;`, { id }, tx);
  return linha.afetadas;
}

module.exports = {
  listar, buscarResumo, criarGestacao, gestacaoDaCrianca, marcarGemelar,
  inserir, atualizar, inativar, reativar, excluirFisico,
};
