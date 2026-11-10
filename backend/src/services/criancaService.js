/**
 * services/criancaService.js — Regras do cadastro de criança e mãe
 * Camada SERVICE: valida, decide e orquestra os repositories dentro
 * de UMA transação (tudo ou nada).
 */
const { transacao } = require('../config/db');
const criancaRepo  = require('../repositories/criancaRepository');
const gestanteRepo = require('../repositories/gestanteRepository');
const { obrigatorios, soDigitos, idValido, ErroNegocio } = require('../utils/validacao');

function limparCrianca(d) {
  return {
    nome: d.nome ? String(d.nome).trim() : null,
    sexo: d.sexo,
    data_nascimento: d.data_nascimento,
    cns: soDigitos(d.cns),
    tipo_sanguineo: d.tipo_sanguineo || null,
    fator_rh: d.fator_rh || null,
    unidade_referencia_id: d.unidade_referencia_id ? Number(d.unidade_referencia_id) : null,
  };
}

const listar = filtros => criancaRepo.listar(filtros);

async function obter(id) {
  const c = await criancaRepo.buscarResumo(idValido(id));
  if (!c) throw new ErroNegocio('Criança não encontrada.', 404);
  return c;
}

/**
 * Cadastro rápido (recepção): criança + mãe.
 * - mãe já cadastrada  -> dados.gestante_id
 * - mãe nova           -> dados.gestante { nome, data_nascimento, cpf|cns, telefones[] }
 * - gêmeo de alguém    -> dados.gemeo_de (id da criança irmã): usa a MESMA gestação
 */
async function criar(dados, usuario) {
  const crianca = limparCrianca(dados);
  crianca.unidade_referencia_id = crianca.unidade_referencia_id || usuario.unidade_id;
  obrigatorios(crianca, [['nome', 'nome da criança'], ['sexo', 'sexo'],
    ['data_nascimento', 'data de nascimento'], ['unidade_referencia_id', 'unidade de referência']]);

  if (!dados.gestante_id && !dados.gestante && !dados.gemeo_de) {
    throw new ErroNegocio('Informe a mãe (busque uma cadastrada ou cadastre uma nova).', 422);
  }

  return transacao(usuario.usuario_id, async tx => {
    let gestacaoId;

    if (dados.gemeo_de) {
      const irma = await criancaRepo.gestacaoDaCrianca(idValido(dados.gemeo_de), tx);
      if (!irma) throw new ErroNegocio('Criança irmã (gêmea) não encontrada.', 404);
      gestacaoId = irma.gestacao_id;
      await criancaRepo.marcarGemelar(gestacaoId, tx);
    } else {
      let gestanteId = dados.gestante_id ? idValido(dados.gestante_id) : null;
      if (!gestanteId) {
        const g = dados.gestante;
        const nova = {
          ...g,
          nome: g.nome ? String(g.nome).trim() : null,
          cpf: soDigitos(g.cpf),
          cns: soDigitos(g.cns),
          cep: soDigitos(g.cep),
          unidade_referencia_id: crianca.unidade_referencia_id,
        };
        obrigatorios(nova, [['nome', 'nome da mãe'], ['data_nascimento', 'nascimento da mãe']]);
        if (!nova.cpf && !nova.cns) throw new ErroNegocio('Informe o CPF ou o CNS da mãe.', 422);
        gestanteId = await gestanteRepo.inserir(nova, tx);
        for (const t of (g.telefones || []).filter(t => t && t.numero)) {
          const numero = soDigitos(t.numero);
          await gestanteRepo.inserirTelefone(gestanteId, {
            ddd: soDigitos(t.ddd) || numero.slice(0, 2),
            numero: t.ddd ? numero : numero.slice(2),
            tipo: t.tipo, whatsapp: t.whatsapp,
          }, tx);
        }
      }
      gestacaoId = await criancaRepo.criarGestacao(gestanteId, tx);
    }

    return criancaRepo.inserir({ ...crianca, gestacao_id: gestacaoId }, tx);
  });
}

async function atualizar(id, dados, usuario) {
  const atual = await obter(id);
  const c = limparCrianca({ ...atual, unidade_referencia_id: atual.unidade_id, ...dados });
  obrigatorios(c, [['nome', 'nome'], ['sexo', 'sexo'], ['data_nascimento', 'data de nascimento']]);
  await transacao(usuario.usuario_id, tx => criancaRepo.atualizar(atual.crianca_id, c, tx));
}

/** Padrão: exclusão LÓGICA. Física só para o gestor, com ?fisico=1 */
async function remover(id, { motivo, fisico }, usuario) {
  const crianca = await obter(id);
  if (fisico) {
    if (usuario.perfil !== 'GESTOR') throw new ErroNegocio('Só a gestão pode excluir definitivamente.', 403);
    await transacao(usuario.usuario_id, tx => criancaRepo.excluirFisico(crianca.crianca_id, tx));
    return { excluido: true };
  }
  if (!motivo || !String(motivo).trim()) throw new ErroNegocio('Informe o motivo da inativação.', 422);
  await transacao(usuario.usuario_id, tx => criancaRepo.inativar(crianca.crianca_id, String(motivo).trim(), tx));
  return { inativado: true };
}

async function reativar(id, usuario) {
  const crianca = await obter(id);
  await transacao(usuario.usuario_id, tx => criancaRepo.reativar(crianca.crianca_id, tx));
}

const buscarGestantes = busca => gestanteRepo.buscar(busca);

module.exports = { listar, obter, criar, atualizar, remover, reativar, buscarGestantes };
