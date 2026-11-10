/**
 * services/cadernetaService.js — Seções da Caderneta (Anexos I.a e I.b)
 * Converte o que vem da tela (texto) nos tipos certos e chama o repository.
 */
const { transacao } = require('../config/db');
const repo = require('../repositories/cadernetaRepository');
const criancaRepo = require('../repositories/criancaRepository');
const { obrigatorios, inteiroOuNulo, decimalOuNulo, boolOuNulo, idValido, ErroNegocio } = require('../utils/validacao');

async function obter(id) {
  const caderneta = await repo.carregar(idValido(id));
  if (!caderneta) throw new ErroNegocio('Criança não encontrada.', 404);
  return caderneta;
}

async function gestacaoOuErro(criancaId, tx) {
  const g = await criancaRepo.gestacaoDaCrianca(criancaId, tx);
  if (!g) throw new ErroNegocio('Criança não encontrada.', 404);
  return g.gestacao_id;
}

async function salvarPrenatal(id, d, usuario) {
  const criancaId = idValido(id);
  const dados = {
    planejada:        boolOuNulo(d.planejada),
    fez_prenatal:     boolOuNulo(d.fez_prenatal),
    numero_consultas: inteiroOuNulo(d.numero_consultas),
    trimestre_inicio: inteiroOuNulo(d.trimestre_inicio),
    tipo_gravidez:    d.tipo_gravidez || null,
    gravidez_risco:   boolOuNulo(d.gravidez_risco),
    risco_descricao:  d.risco_descricao || null,
    dum:              d.dum || null,
    observacao:       d.observacao || null,
    sorologias: (d.sorologias || []).filter(s => s && s.resultado)
      .map(s => ({ agravo_id: Number(s.agravo_id), trimestre: Number(s.trimestre), resultado: s.resultado })),
    vacinas: (d.vacinas || []).map(v => ({ vacina_id: Number(v.vacina_id), recebeu: boolOuNulo(v.recebeu) })),
  };
  if (dados.gravidez_risco && !dados.risco_descricao) throw new ErroNegocio('Gravidez de risco: informe qual.', 422);

  await transacao(usuario.usuario_id, async tx => {
    const gestacaoId = await gestacaoOuErro(criancaId, tx);
    await repo.salvarPrenatal(gestacaoId, dados, tx);
  });
}

async function salvarNascimento(id, d, usuario) {
  const criancaId = idValido(id);
  const dados = {
    data_parto: d.data_parto, local_tipo: d.local_tipo,
    unidade_id: inteiroOuNulo(d.unidade_id), local_descricao: d.local_descricao || null,
    tipo_parto: d.tipo_parto, motivo_cesarea: d.motivo_cesarea || null,
    teve_acompanhante: boolOuNulo(d.teve_acompanhante), acompanhante_descricao: d.acompanhante_descricao || null,
    hora_nascimento: d.hora_nascimento || null,
    contato_pele_a_pele: boolOuNulo(d.contato_pele_a_pele), mamou_primeira_hora: boolOuNulo(d.mamou_primeira_hora),
    apgar_1min: inteiroOuNulo(d.apgar_1min), apgar_5min: inteiroOuNulo(d.apgar_5min),
    clampeamento_oportuno: boolOuNulo(d.clampeamento_oportuno),
    ig_semanas: inteiroOuNulo(d.ig_semanas), ig_dias: inteiroOuNulo(d.ig_dias),
    ig_metodo: d.ig_metodo || null, ig_metodo_descricao: d.ig_metodo_descricao || null,
    peso_g: inteiroOuNulo(d.peso_g), comprimento_cm: decimalOuNulo(d.comprimento_cm),
    perimetro_cefalico_cm: decimalOuNulo(d.perimetro_cefalico_cm),
    reanimacao: boolOuNulo(d.reanimacao), assistido_por_id: inteiroOuNulo(d.assistido_por_id),
    coombs_direto: d.coombs_direto || null, coombs_indireto: d.coombs_indireto || null,
    profilaxia_oftalmica: boolOuNulo(d.profilaxia_oftalmica), vitamina_k: boolOuNulo(d.vitamina_k),
    bebe_tipo_sanguineo: d.bebe_tipo_sanguineo || null, bebe_fator_rh: d.bebe_fator_rh || null,
    mae_tipo_sanguineo: d.mae_tipo_sanguineo || null, mae_fator_rh: d.mae_fator_rh || null,
  };
  obrigatorios(dados, [['data_parto', 'data do parto'], ['local_tipo', 'local do parto'], ['tipo_parto', 'tipo de parto']]);
  if (dados.tipo_parto === 'CESAREA' && !dados.motivo_cesarea) throw new ErroNegocio('Informe o motivo da cesárea.', 422);

  await transacao(usuario.usuario_id, async tx => {
    const gestacaoId = await gestacaoOuErro(criancaId, tx);
    await repo.salvarNascimento(criancaId, gestacaoId, dados, usuario.profissional_id, tx);
  });
}

async function salvarAlta(id, d, usuario) {
  const criancaId = idValido(id);
  const dados = {
    internado: boolOuNulo(d.internado) === true,
    motivo_internacao: d.motivo_internacao || null,
    data_inicio_internacao: d.data_inicio_internacao || null,
    setores: (d.setores || []).map(s => ({ setor_id: Number(s.setor_id), dias: inteiroOuNulo(s.dias) }))
      .filter(s => s.dias > 0),
    data_alta: d.data_alta || null,
    peso_alta_g: inteiroOuNulo(d.peso_alta_g),
    comprimento_alta_cm: decimalOuNulo(d.comprimento_alta_cm),
    aleitamento: d.aleitamento || null,
    resumo_alta: d.resumo_alta || null,
  };
  if (dados.internado && !dados.motivo_internacao) throw new ErroNegocio('Informe o motivo da internação.', 422);
  if (dados.internado && dados.setores.length === 0) throw new ErroNegocio('Informe onde o bebê ficou internado e por quantos dias.', 422);

  await transacao(usuario.usuario_id, tx => repo.salvarAlta(criancaId, dados, usuario.profissional_id, tx));
}

const CODIGOS_TRIAGEM = ['REFLEXO_VERMELHO', 'OXIMETRIA', 'AUDITIVA', 'BIOLOGICA'];

async function salvarTriagem(id, codigo, d, usuario) {
  const criancaId = idValido(id);
  if (!CODIGOS_TRIAGEM.includes(codigo)) throw new ErroNegocio('Tipo de triagem inválido.', 400);
  const dados = {
    realizada: boolOuNulo(d.realizada) === true,
    data_realizacao: d.data_realizacao || null,
    metodo: d.metodo || null,
    data_reteste: d.data_reteste || null,
    conduta: d.conduta || null,
    lados: (d.lados || []).filter(l => l && l.resultado),
    oximetria: (d.oximetria || [])
      .map(o => ({ numero_afericao: inteiroOuNulo(o.numero_afericao), spo2_mao_direita: inteiroOuNulo(o.spo2_mao_direita), spo2_pe: inteiroOuNulo(o.spo2_pe) }))
      .filter(o => o.spo2_mao_direita && o.spo2_pe),
  };
  if (dados.realizada && !dados.data_realizacao) throw new ErroNegocio('Informe a data em que o teste foi feito.', 422);

  return transacao(usuario.usuario_id, tx => repo.salvarTriagem(criancaId, codigo, dados, usuario.profissional_id, tx));
}

module.exports = { obter, salvarPrenatal, salvarNascimento, salvarAlta, salvarTriagem };
