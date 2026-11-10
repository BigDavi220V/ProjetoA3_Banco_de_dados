/* ==========================================================================
   caderneta.js — Tela principal do redesenho: a Caderneta da Criança
   Cada aba corresponde a um bloco dos formulários em papel (Anexos I.a/I.b).
   Cada aba salva separado (PUT na sua rota), com rascunho automático.
   ========================================================================== */
const ID = Number(new URLSearchParams(location.search).get('id'));
let C = null;          // caderneta carregada
let DOM = null;        // domínios
let PROFS = [];        // profissionais (para "RN assistido por")
const EDITA = () => Sessao.pode('caderneta.editar');

if (montarLayout('criancas')) iniciar();

async function iniciar() {
  if (!ID) { location.href = 'criancas.html'; return; }
  $$('[data-perm]').forEach(el => { el.hidden = !Sessao.pode(el.dataset.perm); });
  $$('#abas [data-aba]').forEach(b => b.addEventListener('click', () => trocarAba(b.dataset.aba)));
  window.addEventListener('hashchange', () => trocarAba(location.hash.slice(1) || 'resumo', false));
  try {
    [DOM, PROFS] = await Promise.all([dominios(), api('/profissionais').catch(() => [])]);
    await recarregar();
    trocarAba(location.hash.slice(1) || 'resumo', false);
  } catch (e) {
    $('#ficha').innerHTML = `<div class="card-corpo"><div class="aviso alerta">${esc(e.message)}</div></div>`;
  }
}

async function recarregar() {
  C = await api(`/criancas/${ID}/caderneta`);
  document.title = `${C.resumo.nome} · Caderneta`;
  desenharFicha();
  desenharResumo();
  desenharPrenatal();
  desenharNascimento();
  desenharAlta();
  desenharTriagens();
  desenharConsultas();
  desenharVacinas();
  atualizarMarcadores();
  if (!EDITA()) $$('form:not(#form-vacina) input, form:not(#form-vacina) select, form:not(#form-vacina) textarea, .barra-salvar button')
    .forEach(el => { el.disabled = true; });
}

function trocarAba(aba, mudarHash = true) {
  if (!$(`[data-painel="${aba}"]`)) aba = 'resumo';
  $$('#abas [data-aba]').forEach(b => b.setAttribute('aria-selected', String(b.dataset.aba === aba)));
  $$('[data-painel]').forEach(p => { p.hidden = p.dataset.painel !== aba; });
  if (mudarHash) history.replaceState(null, '', `#${aba}`);
}

/* ------------------------------- Ficha -------------------------------- */
function desenharFicha() {
  const r = C.resumo;
  const motivos = [
    r.alerta_baixo_peso && `baixo peso (${gramas(r.peso_nascer_g)})`,
    r.alerta_prematuro && `prematuro (${r.ig_semanas} semanas)`,
    r.alerta_apgar_baixo && `Apgar ${r.apgar_5min} no 5º minuto`,
    r.alerta_mae_adolescente && `mãe adolescente (${r.idade_mae_no_parto} anos)`,
    r.alerta_utin && 'passou pela UTI neonatal',
  ].filter(Boolean);
  $('#ficha').innerHTML = `
    <div class="ficha">
      <div class="avatar">${iniciais(r.nome)}</div>
      <div>
        <h1>${esc(r.nome)} ${!r.ativo ? '<span class="tag">inativo</span>' : ''}</h1>
        <div class="meta">
          <span><b>${idadeTexto(r.idade_dias)}</b> · nasceu ${dataBR(r.data_nascimento)}</span>
          <span>${r.sexo === 'F' ? 'Feminino' : r.sexo === 'M' ? 'Masculino' : 'Indeterminado'}</span>
          <span>Prontuário <b>${esc(r.prontuario_numero)}</b></span>
          <span>CNS ${esc(r.cns || '—')}</span>
          <span>Mãe: ${esc(r.mae_nome)}</span>
          <span>${esc(r.unidade_nome)}</span>
        </div>
      </div>
      <div class="acoes">
        ${Sessao.pode('agenda.gerenciar') && r.ativo ? `<a class="btn" href="agenda.html?crianca=${r.crianca_id}">Agendar</a>` : ''}
        ${Sessao.pode('consulta.registrar') && r.ativo ? `<button class="btn btn-primario" type="button" onclick="trocarAba('consultas');abrirConsulta()">Registrar consulta</button>` : ''}
      </div>
    </div>
    ${motivos.length ? `<div class="aviso alerta cuidado"><span>⚠</span><span><b>Esta criança merece cuidado especial:</b> ${motivos.join(' · ')}.</span></div>` : ''}
    ${!r.ativo ? `<div class="aviso cuidado">Cadastro inativo: ${esc(r.motivo_inativacao)}</div>` : ''}`;
  $('#lnk-agendar').href = `agenda.html?crianca=${r.crianca_id}`;
}

function atualizarMarcadores() {
  const m = (id, estado) => { const el = $(`#m-${id}`); el.className = `marcador ${estado}`; };
  m('prenatal', C.gestacao.fez_prenatal !== null && C.gestacao.fez_prenatal !== undefined ? 'ok' : '');
  m('nascimento', C.nascimento && C.parto ? 'ok' : 'atencao');
  m('alta', C.alta ? 'ok' : (C.resumo.idade_dias > 2 ? 'atencao' : ''));
  const pend = C.triagens.some(t => ['PENDENTE', 'ATRASADA', 'NAO_REALIZADA'].includes(t.situacao) || ['ALTERADO', 'REPETIR'].includes(t.resultado));
  m('triagens', pend ? 'atencao' : 'ok');
  m('consultas', C.consultas.some(c => c.tipo_atendimento === 'PRIMEIRA_SEMANA') ? 'ok' : (C.resumo.idade_dias >= 3 ? 'atencao' : ''));
  const siglas = new Set(C.vacinas.map(v => v.vacina));
  m('vacinas', C.vacinas.length >= 2 ? 'ok' : (siglas.size ? 'atencao' : ''));
}

/* ------------------------------- Resumo ------------------------------- */
function desenharResumo() {
  $('#timeline').innerHTML = C.linhaTempo.length ? C.linhaTempo.map(e => `
    <li><time>${dataHoraBR(e.data_evento).replace(' 00:00', '')}</time>
      <b>${esc(e.titulo)}</b><span class="muted">${esc(e.detalhe || '')}${e.profissional_nome ? ` · ${esc(e.profissional_nome)}` : ''}</span></li>`).join('')
    : '<li>Nenhum registro ainda.</li>';

  $('#lista-agenda').innerHTML = C.agendamentos.length ? C.agendamentos.slice(0, 8).map(a => `
    <li><span class="pessoa"><b>${dataBR(a.data_hora)} ${horaBR(a.data_hora)} · ${rotulo(a.tipo_atendimento)}</b>
      <small>${esc(a.profissional_nome)} · ${esc(a.unidade_nome)}${a.motivo_cancelamento ? ` · ${esc(a.motivo_cancelamento)}` : ''}</small></span>
      ${tag(a.status)}</li>`).join('') : '<li class="vazio">Sem agendamentos.</li>';

  const g = C.gestacao;
  $('#dados-mae').innerHTML = `
    <div class="pessoa"><b>${esc(g.mae_nome)}</b>
    <small>CPF ${esc(g.mae_cpf || '—')} · CNS ${esc(g.mae_cns || '—')} · ${C.resumo.idade_mae_no_parto} anos no parto</small>
    <small>${esc(g.mae_endereco || '')}</small></div>
    <div class="tags" style="margin-top:10px">${(g.telefones || []).map(t =>
      `<span class="tag ${t.whatsapp ? 'ok' : ''}">(${t.ddd}) ${t.numero} · ${t.tipo.toLowerCase()}${t.whatsapp ? ' · WhatsApp' : ''}</span>`).join('') || '<span class="muted">Sem telefone</span>'}</div>`;
}

/* --------------------- Barra de salvar (padrão) ----------------------- */
/** Troca o <form> por uma cópia limpa (sem os "ouvintes" da renderização anterior) */
function novoForm(sel) {
  const antigo = $(sel);
  const novo = antigo.cloneNode(false);
  antigo.replaceWith(novo);
  return novo;
}

function barra(texto = 'Salvar') {
  return `<div class="barra-salvar"><span class="status-rascunho"></span>
    <button class="btn btn-primario" type="submit">${texto}</button></div>`;
}

/** Liga um formulário de seção: condicionais, rascunho e envio */
function ligarSecao(form, { chave, montarCorpo, caminho, method = 'PUT', rotulo: rot, depois }) {
  const aplicar = ativarCondicionais(form);
  const rasc = EDITA() ? ativarRascunho(form, `${chave}_${ID}`, $('.status-rascunho', form)) : { limpar() {} };
  aplicar();
  form.onsubmit = async e => {
    e.preventDefault();
    const btn = $('button[type=submit]', form);
    btn.disabled = true;
    try {
      const r = await salvarSeguro({ id: `${chave}_${ID}`, caminho, method, body: montarCorpo(lerForm(form)), rotulo: `${rot} — ${C.resumo.nome}` });
      if (!r.offline) {
        rasc.limpar();
        toast(r.mensagem || 'Salvo.', 'ok');
        if (depois) depois();
        const aba = location.hash.slice(1);
        await recarregar();
        trocarAba(aba || 'resumo', false);
      }
    } catch (err) { erroNaTela(err); }
    finally { btn.disabled = false; }
  };
}

/* ------------------------------ Pré-natal ----------------------------- */
function desenharPrenatal() {
  const g = C.gestacao;
  const sor = (agravo, tri) => C.gestacao.sorologias.find(s => s.agravo_id === agravo && s.trimestre === tri)?.resultado;
  const form = novoForm('#form-prenatal');
  form.innerHTML = `
    <div class="secao-form">
      <div class="linha-pergunta"><span class="rotulo">Gravidez planejada?</span>${seg('planejada', SIM_NAO, g.planejada)}</div>
      <div class="linha-pergunta"><span class="rotulo">Fez pré-natal?</span>${seg('fez_prenatal', SIM_NAO, g.fez_prenatal)}</div>
      <div data-mostrar="fez_prenatal=true">
        <div class="linha-pergunta"><span class="rotulo">Número de consultas</span>
          <input name="numero_consultas" type="number" min="0" max="40" style="width:110px" value="${g.numero_consultas ?? ''}"></div>
        <div class="linha-pergunta"><span class="rotulo">Iniciou as consultas no</span>${seg('trimestre_inicio', [['1', '1º tri'], ['2', '2º tri'], ['3', '3º tri']], g.trimestre_inicio)}</div>
      </div>
      <div class="linha-pergunta"><span class="rotulo">Tipo de gravidez</span>${seg('tipo_gravidez', [['UNICA', 'Única'], ['MULTIPLA', 'Múltipla']], g.tipo_gravidez)}</div>
      <div class="linha-pergunta"><span class="rotulo">Gravidez de risco?</span>${seg('gravidez_risco', SIM_NAO, g.gravidez_risco, { alertaSim: true })}</div>
      <div data-mostrar="gravidez_risco=true" class="campo" style="padding-bottom:8px">
        <label class="obrig">Qual risco?</label><input name="risco_descricao" type="text" maxlength="200" value="${esc(g.risco_descricao || '')}"></div>
      <div class="linha-pergunta"><span class="rotulo">DUM <small>data da última menstruação</small></span>
        <input name="dum" type="date" style="width:180px" value="${g.dum || ''}"></div>
    </div>

    <div class="secao-form" data-mostrar="fez_prenatal=true">
      <fieldset style="margin:0">
        <legend>Sorologias do pré-natal (CID-10)</legend>
        <div class="tabela-wrap"><table class="grade">
          <thead><tr><th>Agravo</th><th>1º trimestre</th><th>2º trimestre</th><th>3º trimestre</th></tr></thead>
          <tbody>${DOM.agravos.map(a => `<tr><td><b>${esc(a.cid10)}</b><br><small>${esc(a.nome)}</small></td>
            ${[1, 2, 3].map(t => `<td>${seg(`sor_${a.agravo_id}_${t}`, [['NR', 'NR'], ['N', 'N'], ['ALT', 'ALT']], sor(a.agravo_id, t), { limpar: false })}</td>`).join('')}
          </tr>`).join('')}</tbody></table></div>
        <p class="muted" style="font-size:.8rem;margin:8px 0 0">NR = não realizado · N = normal · ALT = alterado. Deixe em branco o trimestre que ainda não chegou.</p>
      </fieldset>
    </div>

    <div class="secao-form">
      <fieldset style="margin:0"><legend>Vacinas no pré-natal</legend>
        ${C.gestacao.vacinas.map(v => `<div class="linha-pergunta"><span class="rotulo">${esc(v.nome)}</span>${seg(`vac_${v.vacina_id}`, SIM_NAO, v.recebeu)}</div>`).join('')}
      </fieldset>
    </div>
    ${barra('Salvar pré-natal')}`;

  ligarSecao(form, {
    chave: 'prenatal', caminho: `/criancas/${ID}/prenatal`, rotulo: 'Pré-natal',
    montarCorpo: d => ({
      ...d,
      sorologias: DOM.agravos.flatMap(a => [1, 2, 3].map(t => ({ agravo_id: a.agravo_id, trimestre: t, resultado: d[`sor_${a.agravo_id}_${t}`] }))).filter(s => s.resultado),
      vacinas: C.gestacao.vacinas.map(v => ({ vacina_id: v.vacina_id, recebeu: d[`vac_${v.vacina_id}`] })),
    }),
  });
}

/* -------------------------- Parto e nascimento ------------------------ */
function desenharNascimento() {
  const p = C.parto || {}, n = C.nascimento || {}, g = C.gestacao, r = C.resumo;
  const maternidades = DOM.unidades.filter(u => ['MATERNIDADE', 'HOSPITAL', 'CENTRO_PARTO_NORMAL'].includes(u.tipo));
  const assistentes = PROFS.filter(x => ['CRM', 'COREN'].includes(x.conselho));
  $('#adequacao').innerHTML = r.adequacao_peso_ig ? `Peso/IG: ${tag(r.adequacao_peso_ig)}` : '';
  const tipos = [['A', 'A'], ['B', 'B'], ['AB', 'AB'], ['O', 'O']];
  const coombs = [['NEGATIVO', 'Negativo'], ['POSITIVO', 'Positivo'], ['NAO_REALIZADO', 'Não feito']];

  const form = novoForm('#form-nascimento');
  form.innerHTML = `
    <div class="secao-form"><fieldset style="margin:0"><legend>Parto</legend>
      <div class="form-grid">
        <div class="campo c-4"><label class="obrig">Data do parto</label><input name="data_parto" type="date" value="${p.data_parto || r.data_nascimento}" max="${hojeISO()}"></div>
        <div class="campo c-8"><span class="rotulo obrig">Parto em</span>${seg('local_tipo', [['HOSPITAL', 'Hospital'], ['CENTRO_PARTO_NORMAL', 'Centro de Parto Normal'], ['DOMICILIO', 'Domicílio'], ['OUTRO', 'Outro']], p.local_tipo, { limpar: false })}</div>
        <div class="campo c-12" data-mostrar="local_tipo=HOSPITAL|CENTRO_PARTO_NORMAL"><label>Maternidade / Centro de Parto Normal</label>
          <select name="unidade_id">${opcoes(maternidades, 'unidade_id', 'nome', p.unidade_id, 'Fora da rede municipal')}</select></div>
        <div class="campo c-12" data-mostrar="local_tipo=OUTRO|DOMICILIO"><label>Descreva o local</label><input name="local_descricao" type="text" maxlength="150" value="${esc(p.local_descricao || '')}"></div>
        <div class="campo c-6"><span class="rotulo obrig">Tipo de parto</span>${seg('tipo_parto', [['VAGINAL', 'Vaginal'], ['CESAREA', 'Cesárea']], p.tipo_parto, { limpar: false })}</div>
        <div class="campo c-6" data-mostrar="tipo_parto=CESAREA"><label class="obrig">Motivo da cesárea</label><input name="motivo_cesarea" type="text" maxlength="200" value="${esc(p.motivo_cesarea || '')}"></div>
        <div class="campo c-6"><span class="rotulo">Acompanhante no parto?</span>${seg('teve_acompanhante', SIM_NAO, p.teve_acompanhante)}</div>
        <div class="campo c-6" data-mostrar="teve_acompanhante=true"><label>Quem?</label><input name="acompanhante_descricao" type="text" maxlength="100" value="${esc(p.acompanhante_descricao || '')}"></div>
      </div></fieldset></div>

    <div class="secao-form"><fieldset style="margin:0"><legend>Nascimento</legend>
      <div class="form-grid">
        <div class="campo c-3"><label>Hora</label><input name="hora_nascimento" type="time" value="${n.hora_nascimento || ''}"></div>
        <div class="campo c-3"><label>Apgar 1º min</label><input name="apgar_1min" type="number" min="0" max="10" value="${n.apgar_1min ?? ''}"></div>
        <div class="campo c-3"><label>Apgar 5º min</label><input name="apgar_5min" type="number" min="0" max="10" value="${n.apgar_5min ?? ''}"></div>
        <div class="campo c-3"><span class="rotulo">Reanimação?</span>${seg('reanimacao', SIM_NAO, n.reanimacao, { alertaSim: true })}</div>

        <div class="campo c-3"><label>Idade gestacional</label><div class="unidade" data-unidade="sem"><input name="ig_semanas" type="number" min="22" max="44" value="${n.ig_semanas ?? ''}"></div></div>
        <div class="campo c-3"><label>&nbsp;</label><div class="unidade" data-unidade="dias"><input name="ig_dias" type="number" min="0" max="6" value="${n.ig_dias ?? ''}"></div></div>
        <div class="campo c-6"><span class="rotulo">IG calculada por</span>${seg('ig_metodo', [['DUM', 'DUM'], ['USG', 'USG'], ['EXAME_RN', 'Exame do RN'], ['OUTRO', 'Outro']], n.ig_metodo)}</div>
        <div class="campo c-12" data-mostrar="ig_metodo=OUTRO"><label>Qual método?</label><input name="ig_metodo_descricao" type="text" maxlength="100" value="${esc(n.ig_metodo_descricao || '')}"></div>

        <div class="campo c-4"><label>Peso</label><div class="unidade" data-unidade="g"><input name="peso_g" type="number" min="300" max="7000" value="${n.peso_g ?? ''}"></div></div>
        <div class="campo c-4"><label>Comprimento</label><div class="unidade" data-unidade="cm"><input name="comprimento_cm" type="number" step="0.1" min="25" max="65" value="${n.comprimento_cm ?? ''}"></div></div>
        <div class="campo c-4"><label>Perímetro cefálico</label><div class="unidade" data-unidade="cm"><input name="perimetro_cefalico_cm" type="number" step="0.1" min="20" max="45" value="${n.perimetro_cefalico_cm ?? ''}"></div></div>
        <div class="c-12 tags" id="alertas-nasc"></div>

        <div class="campo c-12"><label>RN assistido no parto por</label>
          <select name="assistido_por_id">${opcoes(assistentes, 'profissional_id', 'nome', n.assistido_por_id, 'Não informado')}</select></div>
      </div>
      <div style="margin-top:10px">
        <div class="linha-pergunta"><span class="rotulo">Contato pele a pele</span>${seg('contato_pele_a_pele', SIM_NAO, n.contato_pele_a_pele)}</div>
        <div class="linha-pergunta"><span class="rotulo">Mamou na primeira hora de vida?</span>${seg('mamou_primeira_hora', SIM_NAO, n.mamou_primeira_hora)}</div>
        <div class="linha-pergunta"><span class="rotulo">Clampeamento oportuno do cordão</span>${seg('clampeamento_oportuno', SIM_NAO, n.clampeamento_oportuno)}</div>
        <div class="linha-pergunta"><span class="rotulo">Prevenção oftálmica</span>${seg('profilaxia_oftalmica', SIM_NAO, n.profilaxia_oftalmica)}</div>
        <div class="linha-pergunta"><span class="rotulo">Prevenção hemorrágica (vitamina K)</span>${seg('vitamina_k', SIM_NAO, n.vitamina_k)}</div>
      </div></fieldset></div>

    <div class="secao-form"><fieldset style="margin:0"><legend>Tipo sanguíneo e Coombs</legend>
      <div class="form-grid">
        <div class="campo c-6"><span class="rotulo">Mãe</span><span>${seg('mae_tipo_sanguineo', tipos, g.mae_tipo_sanguineo)} ${seg('mae_fator_rh', [['+', 'Rh +'], ['-', 'Rh −']], g.mae_fator_rh)}</span></div>
        <div class="campo c-6"><span class="rotulo">Coombs indireto (mãe)</span>${seg('coombs_indireto', coombs, g.coombs_indireto)}</div>
        <div class="campo c-6"><span class="rotulo">Bebê</span><span>${seg('bebe_tipo_sanguineo', tipos, r.tipo_sanguineo)} ${seg('bebe_fator_rh', [['+', 'Rh +'], ['-', 'Rh −']], r.fator_rh)}</span></div>
        <div class="campo c-6"><span class="rotulo">Coombs direto (bebê)</span>${seg('coombs_direto', coombs, n.coombs_direto)}</div>
      </div></fieldset></div>
    ${barra('Salvar parto e nascimento')}`;

  // Alertas ao vivo enquanto digita (mesmas regras da view vw_crianca_resumo)
  const alertas = () => {
    const d = lerForm(form), a = [];
    if (d.peso_g && d.peso_g < 2500) a.push('Baixo peso ao nascer (< 2.500 g)');
    if (d.ig_semanas && d.ig_semanas < 37) a.push('Pré-termo (< 37 semanas)');
    if (d.apgar_5min !== null && d.apgar_5min !== '' && Number(d.apgar_5min) < 7) a.push('Apgar < 7 no 5º minuto');
    if (d.local_tipo === 'DOMICILIO' && d.profilaxia_oftalmica === false) a.push('Sem prevenção oftálmica');
    $('#alertas-nasc').innerHTML = a.map(x => `<span class="tag alerta">${x}</span>`).join('');
  };
  form.addEventListener('input', alertas);
  alertas();

  ligarSecao(form, { chave: 'nascimento', caminho: `/criancas/${ID}/nascimento`, rotulo: 'Parto e nascimento', montarCorpo: d => d });
}

/* -------------------------- Internação e alta ------------------------- */
function desenharAlta() {
  const i = C.internacao, a = C.alta || {};
  const dias = id => i?.setores.find(s => s.setor_id === id)?.dias ?? '';
  const form = novoForm('#form-alta');
  form.innerHTML = `
    <div class="secao-form">
      <div class="linha-pergunta"><span class="rotulo">O bebê foi internado?</span>${seg('internado', SIM_NAO, i ? true : (C.alta ? false : null), { alertaSim: true })}</div>
      <div data-mostrar="internado=true">
        <div class="form-grid" style="margin-top:8px">
          <div class="campo c-12"><label class="obrig">Motivo da internação</label><textarea name="motivo_internacao" maxlength="300">${esc(i?.motivo || '')}</textarea></div>
          <div class="campo c-4"><label>Início</label><input name="data_inicio_internacao" type="date" value="${i?.data_inicio || ''}"></div>
          <div class="c-12"><span class="rotulo">Onde ficou e por quantos dias? <small class="muted">(deixe vazio o setor em que não ficou)</small></span>
            <div class="form-grid" style="margin-top:6px">${DOM.setores.map(s => `
              <div class="campo c-3"><label title="${esc(s.nome)}">${esc(s.sigla)}</label>
                <div class="unidade" data-unidade="dias"><input name="setor_${s.setor_id}" type="number" min="1" max="365" value="${dias(s.setor_id)}"></div></div>`).join('')}
            </div></div>
        </div>
      </div>
    </div>

    <div class="secao-form"><fieldset style="margin:0"><legend>Alta</legend>
      <div class="form-grid">
        <div class="campo c-4"><label>Data da alta</label><input name="data_alta" type="date" value="${a.data_alta || ''}" min="${C.resumo.data_nascimento}" max="${hojeISO()}"></div>
        <div class="campo c-4"><label>Peso na alta</label><div class="unidade" data-unidade="g"><input name="peso_alta_g" type="number" min="300" max="7000" value="${a.peso_alta_g ?? ''}"></div></div>
        <div class="campo c-4"><label>Comprimento</label><div class="unidade" data-unidade="cm"><input name="comprimento_alta_cm" type="number" step="0.1" value="${a.comprimento_alta_cm ?? ''}"></div></div>
        <div class="campo c-12"><span class="rotulo">Alimentação na alta</span>${seg('aleitamento', [['LME', 'Leite materno exclusivo'], ['LM_LA', 'Materno + artificial'], ['LA', 'Leite artificial']], a.aleitamento)}</div>
        <div class="campo c-12"><label>Problemas, diagnósticos, tratamentos e recomendações após a alta</label>
          <textarea name="resumo_alta" maxlength="1000" rows="4">${esc(a.resumo_alta || '')}</textarea></div>
      </div></fieldset></div>
    ${barra('Salvar internação e alta')}`;

  ligarSecao(form, {
    chave: 'alta', caminho: `/criancas/${ID}/alta`, rotulo: 'Internação e alta',
    montarCorpo: d => ({ ...d, setores: DOM.setores.map(s => ({ setor_id: s.setor_id, dias: d[`setor_${s.setor_id}`] })).filter(s => s.dias) }),
  });
}

/* ------------------------------ Triagens ------------------------------ */
function resultadoOximetria(afericoes) {
  const validas = afericoes.filter(a => a.spo2_mao_direita && a.spo2_pe);
  if (!validas.length) return null;
  const u = validas[validas.length - 1];
  const mao = Number(u.spo2_mao_direita), pe = Number(u.spo2_pe);
  if (mao >= 95 && pe >= 95 && Math.abs(mao - pe) < 3) return 'NORMAL';
  return u.numero_afericao === 1 ? 'REPETIR' : 'ALTERADO';
}

function desenharTriagens() {
  $('#triagens').innerHTML = C.triagens.map(t => {
    const lado = l => t.lados.find(x => x.lado === l)?.resultado;
    const ox = n => t.oximetria.find(o => o.numero_afericao === n) || {};
    const nr = [['NORMAL', 'Normal'], ['ALTERADO', 'Alterado']];
    let especifico = '';
    if (t.tipo_codigo === 'REFLEXO_VERMELHO') {
      especifico = `
        <div class="linha-pergunta"><span class="rotulo">Olho direito</span>${seg('lado_D', nr, lado('D'))}</div>
        <div class="linha-pergunta"><span class="rotulo">Olho esquerdo</span>${seg('lado_E', nr, lado('E'))}</div>`;
    } else if (t.tipo_codigo === 'AUDITIVA') {
      especifico = `
        <div class="linha-pergunta"><span class="rotulo">Teste</span>${seg('metodo', [['EOA', 'Emissão otoacústica'], ['PEATE', 'PEATE']], t.metodo)}</div>
        <div class="linha-pergunta"><span class="rotulo">Ouvido direito</span>${seg('lado_D', nr, lado('D'))}</div>
        <div class="linha-pergunta"><span class="rotulo">Ouvido esquerdo</span>${seg('lado_E', nr, lado('E'))}</div>`;
    } else if (t.tipo_codigo === 'OXIMETRIA') {
      especifico = `
        <div class="form-grid">
          <div class="campo c-6"><label>1ª aferição · mão direita</label><div class="unidade" data-unidade="%"><input name="ox1_mao" type="number" min="50" max="100" value="${ox(1).spo2_mao_direita ?? ''}"></div></div>
          <div class="campo c-6"><label>1ª aferição · pé</label><div class="unidade" data-unidade="%"><input name="ox1_pe" type="number" min="50" max="100" value="${ox(1).spo2_pe ?? ''}"></div></div>
          <div class="campo c-6 ox2"><label>2ª aferição (após 1h) · mão</label><div class="unidade" data-unidade="%"><input name="ox2_mao" type="number" min="50" max="100" value="${ox(2).spo2_mao_direita ?? ''}"></div></div>
          <div class="campo c-6 ox2"><label>2ª aferição · pé</label><div class="unidade" data-unidade="%"><input name="ox2_pe" type="number" min="50" max="100" value="${ox(2).spo2_pe ?? ''}"></div></div>
        </div>
        <div class="resultado-ao-vivo" id="ox-res"></div>
        <small class="muted">Normal: saturação ≥ 95% nas duas medidas e diferença &lt; 3%.</small>`;
    } else if (t.tipo_codigo === 'BIOLOGICA') {
      especifico = `<div class="linha-pergunta"><span class="rotulo">Reteste <small>se pedido pelo laboratório</small></span>
        <input name="data_reteste" type="date" style="width:180px" value="${t.data_reteste || ''}"></div>`;
    }
    return `
      <form class="triagem" data-codigo="${t.tipo_codigo}" novalidate>
        <header><div><h3>Teste ${esc(t.nome_popular)}</h3><small class="muted">${esc(t.tipo_nome)} · ${esc(t.orientacao_prazo)}</small></div>
          <div class="tags">${t.resultado ? tag(t.resultado) : ''}${tag(t.situacao)}</div></header>
        <div class="corpo">
          <div class="linha-pergunta"><span class="rotulo">Situação</span>${seg('realizada', [['false', 'Não realizado'], ['true', 'Realizado']], t.realizada, { limpar: false })}</div>
          <div data-mostrar="realizada=true">
            <div class="linha-pergunta"><span class="rotulo">Realizado em</span><input name="data_realizacao" type="date" style="width:180px" value="${t.data_realizacao || ''}" min="${C.resumo.data_nascimento}" max="${hojeISO()}"></div>
            ${especifico}
          </div>
          <div class="campo"><label>Observação / encaminhamento</label><textarea name="conduta" rows="2" maxlength="300">${esc(t.conduta || '')}</textarea></div>
          <div style="display:flex;justify-content:space-between;align-items:center;gap:8px">
            <small class="muted">${t.profissional_nome ? `Registrado por ${esc(t.profissional_nome)}` : ''}</small>
            <button class="btn btn-primario btn-sm" type="submit">Salvar teste</button>
          </div>
        </div>
      </form>`;
  }).join('');

  $$('#triagens form').forEach(form => {
    const codigo = form.dataset.codigo;
    const montar = d => ({
      realizada: d.realizada, data_realizacao: d.data_realizacao, metodo: d.metodo, data_reteste: d.data_reteste, conduta: d.conduta,
      lados: ['D', 'E'].map(l => ({ lado: l, resultado: d[`lado_${l}`] })).filter(l => l.resultado),
      oximetria: [1, 2].map(n => ({ numero_afericao: n, spo2_mao_direita: d[`ox${n}_mao`], spo2_pe: d[`ox${n}_pe`] })).filter(o => o.spo2_mao_direita && o.spo2_pe),
    });
    if (codigo === 'OXIMETRIA') {
      const atualizar = () => {
        const d = montar(lerForm(form));
        const r1 = resultadoOximetria(d.oximetria.filter(o => o.numero_afericao === 1));
        $$('.ox2', form).forEach(el => { el.hidden = r1 === 'NORMAL' || r1 === null; });
        const res = resultadoOximetria(d.oximetria);
        const txt = { NORMAL: '✓ Resultado normal', REPETIR: '⚠ Alterado na 1ª aferição: repetir em 1 hora', ALTERADO: '✕ Alterado: encaminhar para ecocardiograma' };
        $('#ox-res', form).innerHTML = res ? `<span class="tag ${CLASSE_TAG[res]}">${txt[res]}</span>` : '';
      };
      form.addEventListener('input', atualizar);
      setTimeout(atualizar);
    }
    ligarSecao(form, { chave: `triagem_${codigo}`, caminho: `/criancas/${ID}/triagens/${codigo}`, rotulo: `Triagem ${codigo}`, montarCorpo: montar });
  });
}

/* ------------------------------ Consultas ----------------------------- */
function desenharConsultas() {
  $('#lista-consultas').innerHTML = C.consultas.length ? `<ul class="lista">${C.consultas.map(c => {
    const variacao = C.resumo.peso_nascer_g && c.peso_g ? ((c.peso_g - C.resumo.peso_nascer_g) / C.resumo.peso_nascer_g * 100) : null;
    return `<li style="align-items:flex-start;flex-direction:column;gap:6px">
      <div style="display:flex;justify-content:space-between;width:100%;gap:10px;flex-wrap:wrap">
        <b>${dataHoraBR(c.data_consulta)} · ${rotulo(c.tipo_atendimento)} ${c.local_atendimento === 'DOMICILIO' ? '(domicílio)' : ''}</b>
        <span class="muted">${esc(c.profissional_nome)} · ${esc(c.especialidade_nome)}</span></div>
      <div class="tags">
        <span class="tag">Peso ${gramas(c.peso_g)}${variacao !== null ? ` (${variacao > 0 ? '+' : ''}${variacao.toFixed(1)}% do nascer)` : ''}</span>
        <span class="tag">Comp. ${c.comprimento_cm ?? '—'} cm</span><span class="tag">PC ${c.perimetro_cefalico_cm ?? '—'} cm</span>
        ${c.aleitamento ? `<span class="tag ${c.aleitamento === 'LME' ? 'ok' : 'atencao'}">${rotulo(c.aleitamento)}</span>` : ''}
        ${c.sinais_presentes ? `<span class="tag alerta">Sinais: ${esc(c.sinais_presentes)}</span>` : (c.tipo_atendimento === 'PRIMEIRA_SEMANA' ? '<span class="tag ok">Sem sinais de alerta</span>' : '')}
        ${c.dificuldade_amamentar ? `<span class="tag atencao">Dificuldade p/ amamentar</span>` : ''}
      </div>
      ${c.desenvolvimento_afeto ? `<small><b>Afeto e rede de apoio:</b> ${esc(c.desenvolvimento_afeto)}</small>` : ''}
      ${c.conduta ? `<small><b>Conduta:</b> ${esc(c.conduta)}</small>` : ''}
    </li>`;
  }).join('')}</ul>` : '<div class="vazio">Nenhuma consulta registrada.</div>';

  $('#btn-nova-consulta').onclick = () => abrirConsulta();
  $('#btn-fechar-consulta').onclick = () => { $('#card-nova-consulta').hidden = true; };
  if (!C.resumo.ativo) $('#btn-nova-consulta').hidden = true;
  if ($('#card-nova-consulta').hidden === false) abrirConsulta(true);
}

function abrirConsulta(manter = false) {
  const u = Sessao.usuario;
  const r = C.resumo;
  const temPrimeira = C.consultas.some(c => c.tipo_atendimento === 'PRIMEIRA_SEMANA');
  const abertos = C.agendamentos.filter(a => a.status === 'AGENDADO');
  const tipoPadrao = temPrimeira ? 'PUERICULTURA' : 'PRIMEIRA_SEMANA';
  const hepB = C.vacinas.find(v => /Hepatite B/i.test(v.vacina));
  const bcg = C.vacinas.find(v => /BCG/i.test(v.vacina));

  $('#card-nova-consulta').hidden = false;
  const prazo = r.idade_dias >= 3 && r.idade_dias <= 5;
  $('#prazo-consulta').innerHTML = `Hoje o bebê está com <b>${idadeTexto(r.idade_dias)}</b>. ` +
    (temPrimeira ? '' : prazo ? '<span class="tag ok">dentro do prazo (3º ao 5º dia)</span>' : '<span class="tag atencao">ideal: do 3º ao 5º dia de vida</span>');

  if (manter && $('#form-consulta').innerHTML) return;
  const form = novoForm('#form-consulta');
  form.innerHTML = `
    <div class="secao-form"><div class="form-grid">
      <div class="campo c-6"><span class="rotulo">Tipo</span>${seg('tipo_atendimento', [['PRIMEIRA_SEMANA', '1ª semana'], ['PUERICULTURA', 'Puericultura'], ['VISITA_DOMICILIAR', 'Visita domiciliar']], tipoPadrao, { limpar: false })}</div>
      <div class="campo c-6"><span class="rotulo">Local</span>${seg('local_atendimento', [['UNIDADE', 'Na unidade'], ['DOMICILIO', 'No domicílio']], 'UNIDADE', { limpar: false })}</div>
      <div class="campo c-6"><label class="obrig">Especialidade</label><select name="especialidade_id">${opcoes(u.especialidades || [], 'especialidade_id', 'nome', (u.especialidades || [])[0]?.especialidade_id)}</select></div>
      <div class="campo c-6"><label>Agendamento</label><select name="agendamento_id">
        <option value="">Sem agendamento (demanda espontânea)</option>
        ${abertos.map(a => `<option value="${a.agendamento_id}" ${a.data_hora.startsWith(hojeISO()) ? 'selected' : ''}>${dataBR(a.data_hora)} ${horaBR(a.data_hora)} · ${rotulo(a.tipo_atendimento)} · ${esc(a.profissional_nome)}</option>`).join('')}
      </select></div>
    </div></div>

    <div class="secao-form"><fieldset style="margin:0"><legend>1. Medidas</legend>
      <div class="form-grid">
        <div class="campo c-4"><label class="obrig">Perímetro cefálico</label><div class="unidade" data-unidade="cm"><input name="perimetro_cefalico_cm" type="number" step="0.1" min="20" max="60" inputmode="decimal"></div></div>
        <div class="campo c-4"><label class="obrig">Peso</label><div class="unidade" data-unidade="g"><input name="peso_g" type="number" min="300" max="30000" inputmode="numeric"></div></div>
        <div class="campo c-4"><label class="obrig">Comprimento</label><div class="unidade" data-unidade="cm"><input name="comprimento_cm" type="number" step="0.1" min="25" max="130" inputmode="decimal"></div></div>
        <div class="c-12" id="variacao-peso"></div>
      </div></fieldset></div>

    <div class="secao-form"><fieldset style="margin:0"><legend>2. Aleitamento / alimentação</legend>
      ${seg('aleitamento', [['LME', 'Leite materno exclusivo'], ['LM_LA', 'Materno + artificial'], ['LA', 'Leite artificial']], null)}
      <div class="campo" data-mostrar="aleitamento=LM_LA|LA" style="margin-top:10px"><label>Por quê / qual leite?</label><input name="aleitamento_observacao" type="text" maxlength="200"></div>
      <div class="linha-pergunta" style="margin-top:6px"><span class="rotulo">Dificuldade para amamentar?</span>${seg('dificuldade_amamentar', SIM_NAO, null, { alertaSim: true })}</div>
      <div class="campo" data-mostrar="dificuldade_amamentar=true"><label class="obrig">Qual dificuldade?</label><input name="dificuldade_descricao" type="text" maxlength="200"></div>
      <div class="linha-pergunta"><span class="rotulo">Parou de amamentar?</span>${seg('parou_amamentar', SIM_NAO, null, { alertaSim: true })}</div>
      <div class="form-grid" data-mostrar="parou_amamentar=true">
        <div class="campo c-4"><label>Com que idade?</label><input name="idade_desmame" type="text" maxlength="40"></div>
        <div class="campo c-8"><label>Motivo do desmame precoce</label><input name="motivo_desmame" type="text" maxlength="200"></div>
      </div></fieldset></div>

    <div class="secao-form"><fieldset style="margin:0">
      <legend style="display:flex;justify-content:space-between;width:100%;align-items:center;gap:10px">3. Sinais de alerta
        <button type="button" class="btn btn-sm" id="btn-sem-sinais">Nenhum sinal de alerta</button></legend>
      ${DOM.sinais.map(s => `<div class="linha-pergunta"><span class="rotulo">${esc(s.nome)}${s.criterio ? ` <small>${esc(s.criterio)}</small>` : ''}</span>
        ${seg(`sinal_${s.sinal_alerta_id}`, SIM_NAO, null, { alertaSim: true })}</div>`).join('')}
      <div class="campo" style="margin-top:8px"><label>Outros</label><input name="outros_sinais" type="text" maxlength="300"></div>
      <p class="muted" style="font-size:.8rem;margin:8px 0 0">Para o manejo dessas situações, consulte o Manual do Quadro AIDPI Neonatal.</p>
      </fieldset></div>

    <div class="secao-form"><fieldset style="margin:0"><legend>4. Vacinas</legend>
      <div class="tags">
        ${hepB ? `<span class="tag ok">Hepatite B · ${dataBR(hepB.data_aplicacao)}</span>` : '<span class="tag atencao">Hepatite B não registrada</span>'}
        ${bcg ? `<span class="tag ok">BCG · ${dataBR(bcg.data_aplicacao)}</span>` : '<span class="tag atencao">BCG não registrada</span>'}
        <button type="button" class="btn-link" onclick="trocarAba('vacinas')">registrar na aba Vacinas</button>
      </div></fieldset></div>

    <div class="secao-form"><fieldset style="margin:0"><legend>5. Desenvolvimento e laços de afeto</legend>
      <p class="muted" style="margin:0 0 8px;font-size:.86rem">Avaliar a rede de apoio materno, participação dos pais, atenção à reação do bebê. A mãe aproveita a mamada para aconchegar, tocar, olhar e conversar com o bebê?</p>
      <textarea name="desenvolvimento_afeto" maxlength="500"></textarea>
      <div class="campo" style="margin-top:10px"><label>Conduta / orientações</label><textarea name="conduta" maxlength="500"></textarea></div>
      </fieldset></div>
    ${barra('Registrar consulta')}`;

  const variacao = () => {
    const d = lerForm(form);
    const el = $('#variacao-peso');
    if (!d.peso_g || !r.peso_nascer_g) { el.innerHTML = ''; return; }
    const v = (d.peso_g - r.peso_nascer_g) / r.peso_nascer_g * 100;
    const cls = v < -10 ? 'alerta' : v < 0 ? 'atencao' : 'ok';
    el.innerHTML = `<span class="tag ${cls}">${v >= 0 ? 'Ganhou' : 'Perdeu'} ${Math.abs(v).toFixed(1)}% em relação ao peso de nascimento (${gramas(r.peso_nascer_g)})${v < -10 ? ' — perda acima de 10%' : ''}</span>`;
  };
  form.addEventListener('input', variacao);
  const titulo = () => { $('#titulo-consulta').textContent = rotulo(lerForm(form).tipo_atendimento); };
  form.addEventListener('change', titulo);
  titulo();

  $('#btn-sem-sinais').onclick = () => {
    DOM.sinais.forEach(s => { const r0 = $(`input[name="sinal_${s.sinal_alerta_id}"][value="false"]`, form); if (r0) r0.checked = true; });
    form.dispatchEvent(new Event('input', { bubbles: true }));
  };

  ligarSecao(form, {
    chave: 'consulta', caminho: `/criancas/${ID}/consultas`, method: 'POST', rotulo: 'Consulta',
    depois: () => { $('#card-nova-consulta').hidden = true; $('#form-consulta').innerHTML = ''; },
    montarCorpo: d => ({ ...d, sinais: DOM.sinais.map(s => ({ sinal_alerta_id: s.sinal_alerta_id, presente: d[`sinal_${s.sinal_alerta_id}`] })).filter(s => s.presente !== null) }),
  });
  variacao();
  $('#card-nova-consulta').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

/* ------------------------------- Vacinas ------------------------------ */
function desenharVacinas() {
  const vacs = DOM.vacinas.filter(v => v.publico_alvo !== 'GESTANTE');
  const form = $('#form-vacina');
  if (!form.dataset.ligado) {
    $('#v-vacina').innerHTML = opcoes(vacs, 'vacina_id', 'nome', null);
    $('#v-data').value = hojeISO();
    $('#v-data').max = hojeISO();
    form.dataset.ligado = '1';
    form.addEventListener('submit', async e => {
      e.preventDefault();
      try {
        const r = await api(`/criancas/${ID}/vacinas`, { method: 'POST', body: lerForm(form) });
        toast(r.mensagem, 'ok');
        $('#v-lote').value = '';
        await recarregar();
      } catch (err) { erroNaTela(err); }
    });
  }
  $('#lista-vacinas').innerHTML = C.vacinas.length ? C.vacinas.map(v => `<tr>
    <td><b>${esc(v.vacina)}</b></td><td>${esc(v.dose)}</td><td>${dataBR(v.data_aplicacao)}</td><td>${esc(v.lote || '—')}</td>
    <td>${esc(v.profissional_nome || '—')}<br><small>${esc(v.unidade_nome)}</small></td>
    <td class="num">${Sessao.pode('vacina.registrar') ? `<button class="btn btn-sm btn-perigo" onclick="excluirVacina(${v.vacina_aplicada_id})">Remover</button>` : ''}</td></tr>`).join('')
    : '<tr><td colspan="6" class="vazio">Nenhuma vacina registrada.</td></tr>';
}

async function excluirVacina(id) {
  const ok = await pedirMotivo({ titulo: 'Remover registro de vacina?', texto: 'Use apenas para corrigir um lançamento errado.', rotuloBotao: 'Remover', obrigatorio: false, perigo: true });
  if (ok === null) return;
  try { const r = await api(`/vacinas-aplicadas/${id}`, { method: 'DELETE' }); toast(r.mensagem, 'ok'); await recarregar(); }
  catch (e) { erroNaTela(e); }
}
