/* ==========================================================================
   app.js — funções compartilhadas por todas as telas
   - sessão (token JWT no navegador)
   - cliente da API com tratamento de erro
   - fila offline: se a rede cair na hora de salvar, guarda no aparelho e
     reenvia sozinho quando a conexão voltar (conectividade instável)
   - menu lateral por perfil, toasts, modais e componentes de formulário
   ========================================================================== */
const API = '/api';

/* ------------------------------- Sessão ------------------------------- */
const Sessao = {
  get token() { return lerLocal('cd_token'); },
  get usuario() { try { return JSON.parse(lerLocal('cd_usuario')); } catch { return null; } },
  salvar(token, usuario) { gravarLocal('cd_token', token); gravarLocal('cd_usuario', JSON.stringify(usuario)); },
  sair() { removerLocal('cd_token'); removerLocal('cd_usuario'); location.href = '/pages/login.html'; },
  pode(permissao) { return (this.usuario?.permissoes || []).includes(permissao); },
};

function lerLocal(k) { try { return localStorage.getItem(k); } catch { return null; } }
function gravarLocal(k, v) { try { localStorage.setItem(k, v); } catch { /* modo privado */ } }
function removerLocal(k) { try { localStorage.removeItem(k); } catch { /* ignore */ } }

/* ----------------------------- Cliente API ---------------------------- */
class ErroApi extends Error {
  constructor(msg, status, rede = false) { super(msg); this.status = status; this.rede = rede; }
}

async function api(caminho, { method = 'GET', body } = {}) {
  let resp;
  try {
    resp = await fetch(API + caminho, {
      method,
      headers: { 'Content-Type': 'application/json', ...(Sessao.token ? { Authorization: `Bearer ${Sessao.token}` } : {}) },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new ErroApi('Sem conexão com o servidor.', 0, true);
  }
  const dados = await resp.json().catch(() => ({}));
  if (resp.status === 401 && !caminho.startsWith('/auth/login')) {
    Sessao.sair();
    throw new ErroApi(dados.erro || 'Sessão expirada.', 401);
  }
  if (!resp.ok) throw new ErroApi(dados.erro || `Erro ${resp.status}`, resp.status);
  return dados;
}

/* --------------------------- Fila offline ----------------------------- */
const Fila = {
  chave: 'cd_fila_pendente',
  itens() { try { return JSON.parse(lerLocal(this.chave)) || []; } catch { return []; } },
  guardar(itens) { gravarLocal(this.chave, JSON.stringify(itens)); atualizarIndicadorConexao(); },
  adicionar(item) { const i = this.itens().filter(x => x.id !== item.id); i.push(item); this.guardar(i); },
  async enviar() {
    const pendentes = this.itens();
    if (!pendentes.length || !navigator.onLine) return;
    const restantes = [];
    for (const p of pendentes) {
      try {
        await api(p.caminho, { method: p.method, body: p.body });
        toast(`Enviado: ${p.rotulo}`, 'ok');
      } catch (e) {
        if (e.rede) restantes.push(p);
        else toast(`Não foi possível enviar "${p.rotulo}": ${e.message}`, 'erro', 7000);
      }
    }
    this.guardar(restantes);
  },
};

/**
 * Salva com proteção de rede: se falhar por conexão, guarda na fila.
 * id = identifica o registro (o mesmo formulário salvo duas vezes offline fica só a última versão).
 */
async function salvarSeguro({ id, caminho, method = 'PUT', body, rotulo }) {
  try {
    return await api(caminho, { method, body });
  } catch (e) {
    if (!e.rede) throw e;
    Fila.adicionar({ id, caminho, method, body, rotulo, em: new Date().toISOString() });
    toast('Sem conexão: salvo neste aparelho. Será enviado quando a internet voltar.', 'atencao', 6000);
    return { offline: true };
  }
}

window.addEventListener('online', () => { atualizarIndicadorConexao(); Fila.enviar(); });
window.addEventListener('offline', atualizarIndicadorConexao);

function atualizarIndicadorConexao() {
  const el = document.getElementById('conexao');
  if (!el) return;
  const pend = Fila.itens().length;
  el.classList.toggle('off', !navigator.onLine || pend > 0);
  el.textContent = !navigator.onLine ? 'Sem conexão' : pend ? `${pend} envio(s) pendente(s)` : 'Conectado';
}

/* ------------------------------ Utilidades ---------------------------- */
const $ = (sel, raiz = document) => raiz.querySelector(sel);
const $$ = (sel, raiz = document) => [...raiz.querySelectorAll(sel)];

function esc(v) {
  return v === null || v === undefined ? '' : String(v)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function dataBR(iso) {
  if (!iso) return '—';
  const [d] = String(iso).split('T');
  const [a, m, dia] = d.split('-');
  return `${dia}/${m}/${a}`;
}
function horaBR(iso) { return iso && String(iso).includes('T') ? String(iso).split('T')[1].slice(0, 5) : ''; }
function dataHoraBR(iso) { return iso ? `${dataBR(iso)} ${horaBR(iso)}`.trim() : '—'; }
function hojeISO(desloc = 0) {
  const d = new Date(); d.setDate(d.getDate() + desloc);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function idadeTexto(dias) {
  if (dias === null || dias === undefined) return '';
  if (dias < 0) return '';
  if (dias === 0) return 'nasceu hoje';
  if (dias < 60) return `${dias} dia${dias === 1 ? '' : 's'} de vida`;
  const meses = Math.floor(dias / 30.44);
  return `${meses} mes${meses === 1 ? '' : 'es'}`;
}
function iniciais(nome) {
  return (nome || '?').split(/\s+/).filter(Boolean).slice(0, 2).map(p => p[0]).join('').toUpperCase();
}
function gramas(v) { return v === null || v === undefined ? '—' : `${Number(v).toLocaleString('pt-BR')} g`; }

const ROTULOS = {
  PRIMEIRA_SEMANA: 'Consulta da 1ª semana', PUERICULTURA: 'Puericultura', TRIAGEM: 'Triagem',
  VACINA: 'Vacina', VISITA_DOMICILIAR: 'Visita domiciliar',
  AGENDADO: 'Agendado', REALIZADO: 'Realizado', CANCELADO: 'Cancelado', FALTOU: 'Faltou',
  UNIDADE: 'Na unidade', DOMICILIO: 'Domicílio',
  LME: 'Leite materno exclusivo', LM_LA: 'Leite materno + artificial', LA: 'Leite artificial',
  PENDENTE: 'Pendente', ATRASADA: 'Atrasada', REALIZADA: 'Realizada', NAO_REALIZADA: 'Não realizada',
  NORMAL: 'Normal', ALTERADO: 'Alterado', REPETIR: 'Repetir aferição', COLETADO: 'Coletado',
  AIG: 'AIG (adequado)', PIG: 'PIG (pequeno)', GIG: 'GIG (grande)',
};
const rotulo = v => ROTULOS[v] || v || '—';

const CLASSE_TAG = {
  AGENDADO: 'info', REALIZADO: 'ok', CANCELADO: '', FALTOU: 'atencao',
  PENDENTE: 'atencao', ATRASADA: 'alerta', REALIZADA: 'ok', NAO_REALIZADA: 'atencao',
  NORMAL: 'ok', ALTERADO: 'alerta', REPETIR: 'atencao', COLETADO: 'ok',
  AIG: 'ok', PIG: 'atencao', GIG: 'atencao',
};
const tag = (v, texto) => `<span class="tag ${CLASSE_TAG[v] ?? ''}">${esc(texto ?? rotulo(v))}</span>`;

/* -------------------------------- Toast ------------------------------- */
function toast(msg, tipo = '', ms = 3800) {
  let box = $('.toasts');
  if (!box) { box = document.createElement('div'); box.className = 'toasts'; box.setAttribute('role', 'status'); document.body.append(box); }
  const t = document.createElement('div');
  t.className = `toast ${tipo}`;
  t.textContent = msg;
  box.append(t);
  setTimeout(() => t.remove(), ms);
}

function erroNaTela(e) { toast(e.message || 'Erro inesperado.', 'erro', 6000); }

/* -------------------------------- Modal ------------------------------- */
function abrirModal(id) { const d = document.getElementById(id); d.showModal(); return d; }
function fecharModal(id) { document.getElementById(id)?.close(); }
document.addEventListener('click', e => {
  const b = e.target.closest('[data-fechar]');
  if (b) b.closest('dialog')?.close();
});

/** Pergunta com motivo (substitui o prompt do navegador) */
function pedirMotivo({ titulo, texto, rotuloBotao = 'Confirmar', obrigatorio = true, perigo = false }) {
  return new Promise(resolve => {
    let d = document.getElementById('dlg-motivo');
    if (!d) {
      d = document.createElement('dialog');
      d.id = 'dlg-motivo';
      document.body.append(d);
    }
    d.innerHTML = `
      <form method="dialog">
        <div class="card-cab"><h2>${esc(titulo)}</h2><button class="fechar" value="cancelar" aria-label="Fechar">×</button></div>
        <div class="modal-corpo">
          <p style="margin-top:0">${esc(texto)}</p>
          <div class="campo"><label for="motivo-txt" class="${obrigatorio ? 'obrig' : ''}">Motivo</label>
          <textarea id="motivo-txt" maxlength="200"></textarea></div>
        </div>
        <div class="modal-rodape">
          <button class="btn" value="cancelar">Voltar</button>
          <button class="btn ${perigo ? 'btn-perigo' : 'btn-primario'}" value="ok">${esc(rotuloBotao)}</button>
        </div>
      </form>`;
    d.addEventListener('close', () => {
      const motivo = $('#motivo-txt', d).value.trim();
      if (d.returnValue !== 'ok') return resolve(null);
      if (obrigatorio && !motivo) { toast('Informe o motivo.', 'erro'); return resolve(null); }
      resolve(motivo || '');
    }, { once: true });
    d.showModal();
    $('#motivo-txt', d).focus();
  });
}

/* -------------------- Componentes de formulário ----------------------- */
/** Botões segmentados (Sim/Não etc). opcoes: [[valor, texto], ...] */
function seg(nome, opcoes, valor, { alertaSim = false, limpar = true } = {}) {
  const v = valor === null || valor === undefined ? '' : String(valor);
  const id = `${nome}-${Math.random().toString(36).slice(2, 7)}`;
  return `<span class="seg-wrap"><span class="seg ${alertaSim ? 'sim-alerta' : ''}" role="radiogroup">
    ${opcoes.map(([val, txt], i) => `
      <input type="radio" name="${nome}" id="${id}-${i}" value="${esc(val)}" ${String(val) === v ? 'checked' : ''}>
      <label for="${id}-${i}">${esc(txt)}</label>`).join('')}
  </span>${limpar ? `<button type="button" class="seg-limpar" data-limpar="${nome}" title="Deixar sem resposta">limpar</button>` : ''}</span>`;
}
const SIM_NAO = [['false', 'Não'], ['true', 'Sim']];

document.addEventListener('click', e => {
  const b = e.target.closest('[data-limpar]');
  if (!b) return;
  const form = b.closest('form');
  $$(`input[name="${b.dataset.limpar}"]`, form).forEach(r => { r.checked = false; });
  form.dispatchEvent(new Event('input', { bubbles: true }));
});

/** Lê um <form> como objeto. Valores "true"/"false" viram booleanos. */
function lerForm(form) {
  const obj = {};
  for (const el of form.elements) {
    if (!el.name || el.disabled) continue;
    if (el.type === 'radio') { if (el.checked) obj[el.name] = conv(el.value); else if (!(el.name in obj)) obj[el.name] = null; continue; }
    if (el.type === 'checkbox') { obj[el.name] = el.checked; continue; }
    obj[el.name] = el.value === '' ? null : el.value;
  }
  return obj;
}
const conv = v => (v === 'true' ? true : v === 'false' ? false : v);

/** Preenche um <form> a partir de um objeto */
function preencherForm(form, dados) {
  if (!dados) return;
  for (const el of form.elements) {
    if (!el.name || !(el.name in dados)) continue;
    const v = dados[el.name];
    if (el.type === 'radio') el.checked = v !== null && v !== undefined && String(v) === el.value;
    else if (el.type === 'checkbox') el.checked = !!v;
    else el.value = v === null || v === undefined ? '' : (el.type === 'date' ? String(v).slice(0, 10) : v);
  }
}

/**
 * Campos condicionais: <div data-mostrar="campo=valor|outro"> aparece só
 * quando o campo tem um desses valores. Diminui o que a pessoa vê/preenche.
 */
function ativarCondicionais(form) {
  const aplicar = () => {
    const d = lerForm(form);
    $$('[data-mostrar]', form).forEach(bloco => {
      const [campo, valores] = bloco.dataset.mostrar.split('=');
      const ok = valores.split('|').includes(String(d[campo]));
      bloco.hidden = !ok;
      $$('input, select, textarea', bloco).forEach(i => { i.disabled = !ok; });
    });
  };
  form.addEventListener('input', aplicar);
  form.addEventListener('change', aplicar);
  aplicar();
  return aplicar;
}

/**
 * Rascunho automático: cada digitação fica guardada no aparelho.
 * Se a pessoa for interrompida (atender um bebê, cair a rede, fechar a aba),
 * ao voltar o formulário reaparece como estava.
 */
function ativarRascunho(form, chave, statusEl) {
  const k = `cd_rascunho_${chave}`;
  const salvo = lerLocal(k);
  if (salvo) {
    try {
      const d = JSON.parse(salvo);
      preencherForm(form, d.valores);
      if (statusEl) statusEl.textContent = `Rascunho recuperado (${new Date(d.em).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })})`;
    } catch { /* ignora rascunho corrompido */ }
  }
  let t;
  form.addEventListener('input', () => {
    clearTimeout(t);
    t = setTimeout(() => {
      gravarLocal(k, JSON.stringify({ em: Date.now(), valores: lerForm(form) }));
      if (statusEl) statusEl.textContent = 'Rascunho guardado neste aparelho';
    }, 400);
  });
  return { limpar: () => { removerLocal(k); if (statusEl) statusEl.textContent = ''; }, tem: !!salvo };
}

/* -------------------------- Domínios (cache) -------------------------- */
let _dominios;
async function dominios() {
  if (_dominios) return _dominios;
  try { const c = sessionStorage.getItem('cd_dominios'); if (c) return (_dominios = JSON.parse(c)); } catch { /* ignore */ }
  _dominios = await api('/dominios');
  try { sessionStorage.setItem('cd_dominios', JSON.stringify(_dominios)); } catch { /* ignore */ }
  return _dominios;
}
const opcoes = (lista, valorKey, textoKey, selecionado, vazio = 'Selecione...') =>
  `<option value="">${vazio}</option>` + lista.map(i =>
    `<option value="${esc(i[valorKey])}" ${String(i[valorKey]) === String(selecionado ?? '') ? 'selected' : ''}>${esc(i[textoKey])}</option>`).join('');

/* -------------------------------- Layout ------------------------------ */
const ICONES = {
  inicio: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/><path d="M10 21v-6h4v6"/>',
  criancas: '<circle cx="12" cy="7" r="3.2"/><path d="M5.5 21v-1.5A5.5 5.5 0 0 1 11 14h2a5.5 5.5 0 0 1 5.5 5.5V21"/>',
  agenda: '<rect x="3.5" y="5" width="17" height="15.5" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  profissionais: '<circle cx="9" cy="8" r="3"/><path d="M3 20v-1a5 5 0 0 1 5-5h2a5 5 0 0 1 5 5v1"/><path d="M16 4.5a3 3 0 0 1 0 6M18 14a5 5 0 0 1 3 4.6V20"/>',
  relatorios: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
};
const icone = n => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONES[n] || ''}</svg>`;

const MENU = [
  { id: 'inicio', rotulo: 'Início', href: 'inicio.html', perm: 'dashboard.ver' },
  { id: 'criancas', rotulo: 'Crianças', href: 'criancas.html', perm: 'criancas.ver' },
  { id: 'agenda', rotulo: 'Agenda', href: 'agenda.html', perm: 'agenda.ver' },
  { id: 'profissionais', rotulo: 'Profissionais', href: 'profissionais.html', perm: 'profissionais.ver' },
  { id: 'relatorios', rotulo: 'Relatórios', href: 'relatorios.html', perm: 'relatorios.ver' },
];

/** Monta menu lateral + topo móvel. Chame no início de cada tela protegida. */
function montarLayout(paginaAtual) {
  if (!Sessao.token) { location.href = '/pages/login.html'; return false; }
  const u = Sessao.usuario || {};
  const app = $('.app');
  const aside = document.createElement('aside');
  aside.className = 'sidebar';
  aside.innerHTML = `
    <a class="marca" href="inicio.html"><span class="marca-icone">CD</span><span><b>Caderneta Digital</b><span>da Criança · Rede Municipal</span></span></a>
    <nav class="nav" aria-label="Menu principal">
      ${MENU.filter(m => Sessao.pode(m.perm)).map(m =>
        `<a href="${m.href}" ${m.id === paginaAtual ? 'aria-current="page"' : ''}>${icone(m.id)}${m.rotulo}</a>`).join('')}
    </nav>
    <div class="sidebar-rodape">
      <b>${esc(u.nome)}</b>${esc(u.perfil_nome || u.perfil || '')}
      <div><span class="conexao" id="conexao">Conectado</span></div>
      <button type="button" id="btn-sair">Sair</button>
    </div>`;
  app.prepend(aside);

  const topo = document.createElement('div');
  topo.className = 'menu-movel';
  topo.innerHTML = `<button type="button" aria-label="Abrir menu" id="btn-menu">☰</button><b>Caderneta Digital</b>`;
  document.body.prepend(topo);
  $('#btn-menu').onclick = () => aside.classList.toggle('aberta');
  $('#btn-sair').onclick = () => Sessao.sair();
  atualizarIndicadorConexao();
  Fila.enviar();
  return true;
}
