import re, markdown, html
import os
R=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D=R+'/docs/'
def md(t, shift=0):
    t=re.sub(r'```mermaid.*?```','',t,flags=re.S)
    # details -> bloco simples
    t=re.sub(r'<details><summary>(.*?)</summary>\s*','\n<p class="rotulo-sql">\\1</p>\n\n',t)
    t=t.replace('</details>','')
    h=markdown.markdown(t,extensions=['tables','fenced_code'])
    if shift:
        for n in range(5,0,-1): h=h.replace(f'<h{n}',f'<h{n+shift}').replace(f'</h{n}>',f'</h{n+shift}>')
    return h
def ler(n): return open(D+n,encoding='utf8').read()
def sem_titulo(t): return re.sub(r'^# .*\n','',t,count=1)

secoes=[]
# 1 Contextualização + 2 requisitos (do doc 05)
req=sem_titulo(ler('05-requisitos-e-regras-de-negocio.md'))
partes=req.split('## Atores')
secoes.append(('Contextualização e justificativa do cenário', md(partes[0],0)))
secoes.append(('Levantamento de requisitos e regras de negócio', md('## Atores'+partes[1],0)))
# 3 arquitetura do banco
secoes.append(('Arquitetura do banco de dados', md(sem_titulo(ler('01-arquitetura-do-banco.md')))))
# 4 DER
der=sem_titulo(ler('02-der.md'))
der=re.sub(r'!\[DER\]\(img/der.png\)','',der)
der=der.replace('Versão vetorial (alta resolução, para o relatório): [`img/der.svg`](img/der.svg). Fonte editável: [`der.mmd`](der.mmd) (Mermaid; abre no VS Code, no GitHub ou em mermaid.live).','O diagrama em alta resolução está na página seguinte (arquivo vetorial `docs/img/der.svg` no repositório; fonte editável em `docs/der.mmd`).')
der=der.replace('[dicionário de dados](04-dicionario-de-dados.md)','dicionário de dados (seção 6)')
der=der.split('## Código-fonte do diagrama')[0]
svg=open(D+'img/der.svg',encoding='utf8').read()
svg=re.sub(r'^<\?xml[^>]*>','',svg)
der_html=md(der)+'<section class="paisagem"><h3 class="der-tit">Figura 1 — Diagrama Entidade-Relacionamento (CadernetaDigital)</h3><img class="der" src="file://'+D+'img/der.svg"></section>'
secoes.append(('Diagrama Entidade-Relacionamento (DER)', der_html))
# 5 normalização
secoes.append(('Memorial de normalização (até a 3FN)', md(sem_titulo(ler('03-normalizacao-3fn.md')))))
# 6 dicionário
dic=sem_titulo(ler('04-dicionario-de-dados.md'))
secoes.append(('Dicionário de dados', md(dic)))
# 7 arquitetura da aplicação + telas
app=sem_titulo(ler('07-arquitetura-da-aplicacao.md'))
telas=''.join(f'<figure><img src="file://{D}img/{f}"><figcaption>{c}</figcaption></figure>' for f,c in [
 ('tela-inicio.png','Figura 2 — Tela Início: pendências do dia (consultas, triagens e cuidado especial)'),
 ('tela-consulta.png','Figura 3 — Registro da Consulta da 1ª semana redesenhado'),
 ('tela-triagens.png','Figura 4 — Triagens neonatais com resultado calculado (teste do coraçãozinho)'),
 ('tela-relatorios.png','Figura 5 — Relatórios gerenciais exibindo o SQL executado')])
secoes.append(('Aplicação: arquitetura, CRUD e interface', md(app)+'<h3>Telas do sistema</h3>'+telas))
# 8 scripts + execução
scripts=sem_titulo(open(R+'/database/README.md',encoding='utf8').read())
guia=sem_titulo(ler('06-guia-vm-sqlserver-dbeaver.md'))
secoes.append(('Pacote de scripts SQL e instruções de execução', '<h3>Organização dos scripts</h3>'+md(scripts)+md(guia)))

# índice
toc=''.join(f'<li><span>{i}. {html.escape(t)}</span></li>' for i,(t,_) in enumerate(secoes,1))
corpo=''.join(f'<section class="secao"><h1><span class="num">{i}</span>{html.escape(t)}</h1>{h}</section>' for i,(t,h) in enumerate(secoes,1))
# numerar h2 dentro de cada seção
def numerar(c):
    out=[];sec=0
    for parte in re.split(r'(<section class="secao">)',c):
        if parte=='<section class="secao">': sec+=1; out.append(parte); continue
        k=[0]
        def rep(m):
            k[0]+=1; return f'<h2>{sec}.{k[0]} '
        out.append(re.sub(r'<h2>',rep,parte) if sec else parte)
    return ''.join(out)
corpo=numerar(corpo)
css=open(os.path.dirname(os.path.abspath(__file__))+'/rel.css').read()
doc=f'''<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8"><title>Relatório Técnico — Caderneta Digital da Criança</title><style>{css}</style></head><body>
<section class="capa">
 <div class="inst">UNIFACS — Universidade Salvador<br>Análise e Desenvolvimento de Sistemas · Banco de Dados · 2026.2</div>
 <div class="meio">
  <div class="tag">Avaliação A3 · Projeto Integrador</div>
  <h1>Caderneta Digital da Criança</h1>
  <p class="sub">Projeto de Banco de Dados e Aplicação — cenário Clínica SaúdeDigital, contexto de redesenho de atendimento</p>
  <p class="trilha">Trilha Oracle Academy: Database Design &amp; Programming with SQL</p>
 </div>
 <div class="equipe">
  <p><b>Relatório Técnico Completo</b></p>
  <p>Integrantes:<br>Davi Santiago de Jesus<br>________________________________<br>________________________________<br>________________________________</p>
  <p>Professor(a): ________________________________</p>
  <p>Salvador — BA, novembro de 2026</p>
 </div>
</section>
<section class="sumario"><h1>Sumário</h1><ol class="toc">{toc}</ol>
<div class="ficha-tec"><h3>Ficha técnica</h3><table>
<tr><th>SGBD</th><td>Microsoft SQL Server 2022 (T-SQL) em VM Oracle VirtualBox (Ubuntu Server 22.04)</td></tr>
<tr><th>Banco</th><td>CadernetaDigital — 7 schemas, 33 tabelas, 5 views, 4 funções, 5 procedures, 9 triggers</td></tr>
<tr><th>Aplicação</th><td>Node.js + Express (API em camadas) · HTML, CSS e JavaScript</td></tr>
<tr><th>Inspeção</th><td>DBeaver / SQL Server Management Studio</td></tr>
<tr><th>Repositório</th><td>pasta <code>CadernetaDigital_A3</code> (database/, backend/, frontend/, docs/)</td></tr>
</table></div></section>
{corpo}
</body></html>'''
open(os.path.dirname(os.path.abspath(__file__))+'/relatorio.html','w',encoding='utf8').write(doc)
print('ok')
