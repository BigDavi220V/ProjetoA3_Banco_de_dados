/**
 * middlewares/errorHandler.js — Transforma erros do SQL Server em
 * mensagens que a equipe de saúde entende.
 *
 *   50000+  -> THROW das nossas procedures/triggers (regra de negócio)
 *   2627/2601 -> violação de UNIQUE (registro duplicado)
 *   547     -> violação de FOREIGN KEY ou CHECK
 *   515     -> tentativa de gravar NULL em coluna NOT NULL
 */
const MENSAGENS_RESTRICAO = {
  ck_parto_cesarea:          'Informe o motivo da cesárea.',
  ck_parto_local_outro:      'Descreva o local do parto quando marcar "Outro".',
  ck_gestacao_prenatal:      'Se a mãe não fez pré-natal, não informe número de consultas nem trimestre.',
  ck_gestacao_risco:         'Gravidez de risco: informe qual é o risco.',
  ck_triagem_data:           'Triagem realizada precisa de data (e não realizada não pode ter data).',
  ck_triagem_reteste:        'A data do reteste não pode ser antes da coleta.',
  ck_consulta_medidas_1sem:  'Na consulta da 1ª semana, peso, comprimento e PC são obrigatórios.',
  ck_consulta_dificuldade:   'Descreva a dificuldade para amamentar.',
  ck_crianca_nascimento:     'A data de nascimento não pode estar no futuro.',
  ck_crianca_inativacao:     'Informe o motivo da inativação.',
  ck_agendamento_cancelado:  'Informe o motivo do cancelamento.',
  ck_gestante_documento:     'Informe o CPF ou o CNS da mãe.',
  ck_nascimento_apgar_ordem: 'Informe o Apgar do 1º minuto antes do 5º.',
  ck_nascimento_metodo_outro:'Descreva o método usado para calcular a IG.',
  uq_crianca_cns:            'Já existe uma criança com este CNS.',
  uq_gestante_cpf:           'Já existe uma gestante com este CPF.',
  uq_gestante_cns:           'Já existe uma gestante com este CNS.',
  uq_agendamento_profissional_horario: 'O profissional já tem um atendimento nesse horário.',
  uq_vacina_aplicada_dose:   'Esta dose desta vacina já foi registrada para a criança.',
  fk_agendamento_crianca:    'A criança tem agendamentos: use a inativação em vez de excluir.',
  fk_consulta_crianca:       'A criança tem consultas registradas: use a inativação em vez de excluir.',
};

function traduzirErroSql(err) {
  // Quando o SQL Server devolve vários erros no mesmo lote, o driver lança o último
  // e guarda os anteriores em precedingErrors. Damos preferência ao THROW de negócio (50000+).
  const todos = [err, ...(err.precedingErrors || [])];
  const negocio = todos.find(e => (e.number ?? e.originalError?.info?.number) >= 50000);
  if (negocio) return { status: 422, erro: negocio.message };

  const numero = err.number ?? err.originalError?.info?.number;
  const texto  = todos.map(e => e.message || '').join(' ');
  if (!numero) return null;

  if (numero >= 50000) return { status: 422, erro: texto };

  const restricao = Object.keys(MENSAGENS_RESTRICAO).find(nome => texto.includes(nome));
  if (restricao) return { status: numero === 547 ? 422 : 409, erro: MENSAGENS_RESTRICAO[restricao], restricao };

  if (numero === 2627 || numero === 2601) return { status: 409, erro: 'Registro duplicado.' };
  if (numero === 547)  return { status: 422, erro: 'Os dados violam uma regra do banco (chave estrangeira ou validação).' };
  if (numero === 515)  return { status: 422, erro: 'Há um campo obrigatório sem preenchimento.' };
  if (numero === 8152 || numero === 2628) return { status: 422, erro: 'Algum texto ficou maior do que o permitido.' };
  return null;
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (err.status && err.publico) {
    return res.status(err.status).json({ erro: err.message });
  }
  const traduzido = traduzirErroSql(err);
  if (traduzido) {
    return res.status(traduzido.status).json({ erro: traduzido.erro, restricao: traduzido.restricao });
  }
  if (err.code === 'ESOCKET' || err.code === 'ELOGIN' || err.code === 'ETIMEOUT') {
    console.error('[DB]', err.message);
    return res.status(503).json({ erro: 'Banco de dados indisponível. Verifique se o SQL Server está em execução e configurado.' });
  }
  console.error('[Erro]', err);
  return res.status(500).json({ erro: 'Erro interno no servidor.' });
}

/** Erro "esperado" com mensagem que pode ir para a tela */
class ErroNegocio extends Error {
  constructor(mensagem, status = 400) {
    super(mensagem);
    this.status = status;
    this.publico = true;
  }
}

module.exports = { errorHandler, ErroNegocio, traduzirErroSql };
