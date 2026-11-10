"""
gerar_dicionario.py — Gera docs/04-dicionario-de-dados.md lendo os CREATE TABLE
dos scripts DDL. Assim o dicionário nunca fica diferente do banco.
Uso (na raiz do projeto):  python database/ferramentas/gerar_dicionario.py
"""
import re, glob, os
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FINALIDADE = {
 'dominio.especialidade':'Especialidades em que os profissionais atendem (Pediatria, Neonatologia...).',
 'dominio.categoria_profissional':'Categoria do profissional e o conselho que a regula (CRM, COREN, CRFa).',
 'dominio.agravo':'Agravos pesquisados nas sorologias do pré-natal, com código CID-10.',
 'dominio.vacina':'Vacinas da gestante e do recém-nascido.',
 'dominio.tipo_triagem':'Os quatro testes da triagem neonatal e seus prazos.',
 'dominio.sinal_alerta':'Sinais de alerta avaliados na consulta da 1ª semana.',
 'dominio.setor_internacao':'Setores de internação neonatal (UTIN, UCINCo, UCINCa, Alojamento Conjunto).',
 'dominio.referencia_peso_ig':'Percentis 10 e 90 de peso por idade gestacional e sexo (classificação AIG/PIG/GIG).',
 'cadastro.unidade_saude':'Unidades da rede: UBS/USF, maternidades, centro de parto e hospital.',
 'cadastro.profissional':'Profissionais de saúde e administrativos (edital: entidade Médico, generalizada).',
 'cadastro.profissional_especialidade':'Associativa N:N entre profissional e especialidade.',
 'cadastro.gestante':'Mãe / gestante. Endereço (atributo composto) decomposto em colunas.',
 'cadastro.gestante_telefone':'Telefones da gestante (atributo multivalorado normalizado).',
 'clinico.gestacao':'Cada gravidez da gestante; eixo que liga mãe, parto e filhos.',
 'clinico.sorologia_prenatal':'Uma linha por célula da grade agravo × trimestre do formulário.',
 'clinico.vacina_prenatal':'Vacinas recebidas pela gestante no pré-natal.',
 'clinico.parto':'Parto da gestação (1:1). Local e tipo de parto.',
 'cadastro.crianca':'Criança acompanhada pela caderneta (edital: entidade Paciente).',
 'clinico.prontuario':'Prontuário da criança (1:1), aberto automaticamente por trigger.',
 'clinico.nascimento':'Dados do nascimento de cada bebê (Apgar, IG, medidas, profilaxias).',
 'clinico.internacao_neonatal':'Internação neonatal, quando houve.',
 'clinico.internacao_setor':'Setores e dias de internação (multivalorado).',
 'clinico.alta_maternidade':'Alta da maternidade: data, medidas, alimentação e resumo.',
 'clinico.triagem_neonatal':'Um registro por criança e tipo de triagem.',
 'clinico.triagem_resultado_lado':'Resultado por lado (olho/ouvido direito e esquerdo).',
 'clinico.oximetria_afericao':'Aferições de saturação do teste do coraçãozinho.',
 'seguranca.perfil':'Perfis de acesso do sistema.',
 'seguranca.usuario':'Usuários do sistema (senha guardada como hash bcrypt).',
 'auditoria.log_auditoria':'Histórico de alterações gravado pelos triggers (antes/depois em JSON).',
 'atendimento.agendamento':'Agenda: o que foi marcado (exclusão lógica = CANCELADO).',
 'atendimento.consulta':'Consulta realizada (edital: entidade Consulta). Inclui a 1ª semana.',
 'atendimento.consulta_sinal_alerta':'Resposta Sim/Não de cada sinal de alerta na consulta.',
 'atendimento.vacina_aplicada':'Vacinas aplicadas na criança.',
}
out = ['# 4. Dicionário de dados', '',
       '> Gerado automaticamente a partir de `database/01_ddl` por `database/ferramentas/gerar_dicionario.py`.',
       '> Legenda: **PK** chave primária · **FK** chave estrangeira · **UQ** único · **CK** regra CHECK · **DF** valor padrão.', '']
for arq in sorted(glob.glob(os.path.join(RAIZ, 'database/01_ddl/*_tabelas_*.sql'))):
    sql = open(arq, encoding='utf8').read()
    for m in re.finditer(r'CREATE TABLE (\w+\.\w+) \((.*?)\n\);', sql, re.S):
        tabela, corpo = m.group(1), m.group(2)
        linhas = [l.rstrip() for l in corpo.split('\n') if l.strip()]
        cols, cons = [], []
        for l in linhas:
            t = l.strip()
            if t.startswith('--'): continue
            if t.startswith('CONSTRAINT'):
                cons.append(re.sub(r'\s+', ' ', t.rstrip(',')))
                continue
            cm = re.match(r'(\w+)\s+([A-Z]+(?:\([\d, ]+\))?)(.*)', t)
            if not cm: continue
            nome, tipo, resto = cm.groups()
            coment = ''
            if '--' in resto: resto, coment = resto.split('--', 1)
            cols.append((nome, tipo, 'não' if 'NOT NULL' in resto else 'sim',
                         'IDENTITY' if 'IDENTITY' in resto else ('DEFAULT ' + re.search(r'DEFAULT \((.*?)\)\s*,?$', resto.strip()).group(1)) if 'DEFAULT' in resto and re.search(r'DEFAULT \((.*?)\)\s*,?$', resto.strip()) else '',
                         coment.strip()))
        regras = {}
        for c in cons:
            n = c.split()[1]
            for col in re.findall(r'\b(\w+)\b', c):
                regras.setdefault(col, set())
            mm = re.search(r'(PRIMARY KEY|UNIQUE|FOREIGN KEY|CHECK)\s*\((.*?)\)', c)
            if mm:
                tipo = {'PRIMARY KEY':'PK','UNIQUE':'UQ','FOREIGN KEY':'FK','CHECK':'CK'}[mm.group(1)]
                for col in re.findall(r'\w+', mm.group(2)):
                    if col in [x[0] for x in cols]:
                        regras[col].add(tipo + (' → ' + re.search(r'REFERENCES (\S+ \(\w+\))', c).group(1) if tipo == 'FK' else ''))
        out += [f'## `{tabela}`', '', FINALIDADE.get(tabela, ''), '',
                '| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |', '|---|---|---|---|---|---|']
        for nome, tipo, nulo, padrao, coment in cols:
            r = ', '.join(sorted(regras.get(nome, set())))
            out.append(f'| `{nome}` | {tipo} | {nulo} | {r} | {padrao} | {coment} |')
        out += ['', '<details><summary>Restrições (constraints)</summary>', '', '```sql', *cons, '```', '</details>', '']
open(os.path.join(RAIZ, 'docs/04-dicionario-de-dados.md'), 'w', encoding='utf8').write('\n'.join(out))
print('Dicionário gerado.')
