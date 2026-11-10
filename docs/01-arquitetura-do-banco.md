# 1. Arquitetura do banco: explicação fácil

> Leia isto antes da apresentação. A ideia é que **qualquer pessoa do grupo** consiga explicar o banco para a banca.

## A analogia

Pense no banco como **um arquivo de hospital**:

| No hospital | No banco de dados | Onde está no projeto |
|---|---|---|
| O prédio do arquivo | o **banco** `CadernetaDigital` | `01_ddl/01_create_database.sql` |
| As salas (uma por assunto) | os **schemas** | `01_ddl/02_create_schemas.sql` |
| Os armários dentro das salas | as **tabelas** | `01_ddl/04…09_tabelas_*.sql` |
| O índice remissivo das pastas | os **índices** | `01_ddl/10_indices.sql` |
| Os "carimbos" que conferem as fichas | **CHECK, FK, UNIQUE, NOT NULL** | dentro de cada tabela |
| Os relatórios prontos | as **views** | `02_programabilidade/02_views.sql` |
| As rotinas com passo a passo | as **procedures** | `02_programabilidade/03_procedures.sql` |
| O funcionário que reage sozinho | os **triggers** | `02_programabilidade/04_triggers.sql` |
| O crachá de cada funcionário | **logins, users e roles** | `05_dcl/…` |

## As 7 salas (schemas)

Separamos as tabelas por assunto, do mesmo jeito que o backend é separado em pastas:

```
CadernetaDigital
├── dominio      listas fixas: vacinas, agravos CID-10, tipos de triagem, sinais de alerta, setores
├── cadastro     quem é quem: unidades, profissionais, gestantes, telefones, crianças
├── clinico      o que aconteceu: gestação, sorologias, parto, nascimento, internação, alta, triagens
├── atendimento  agenda, consultas, sinais de alerta da consulta, vacinas aplicadas
├── seguranca    perfis e usuários do sistema
├── auditoria    log de alterações (só os triggers escrevem)
└── relatorio    views e procedures para a gestão
```

**Por que separar?**
1. **Leitura:** `clinico.nascimento` já diz de que assunto é a tabela.
2. **Segurança:** a permissão é dada **por schema**. A role da aplicação pode ler e gravar em `cadastro`, `clinico` e `atendimento`, mas só ler `auditoria` (ver `05_dcl`). A role da gestão só enxerga `relatorio`.
3. **Organização do DER:** cada cor/bloco do diagrama é um schema.

## As 4 camadas de objetos

```
        ┌───────────────────────────────────────────────┐
  App → │ 4. PROCEDURES   regras com vários passos       │  sp_agendar_consulta, sp_registrar_consulta...
        │ 3. VIEWS        leitura pronta (JOINs + cálculos) │  vw_crianca_resumo, vw_triagem_situacao...
        │ 2. FUNÇÕES      cálculos clínicos reutilizáveis │  fn_classificar_peso_ig, fn_resultado_oximetria
        │ 1. TABELAS      os dados, protegidos por regras │  PK, FK, CHECK, UNIQUE, NOT NULL
        └───────────────────────────────────────────────┘
          + TRIGGERS vigiando as tabelas (auditoria, prontuário automático, datas)
```

- A aplicação **lê** quase tudo pelas **views**, que já trazem os nomes e os cálculos (idade em dias, AIG/PIG/GIG, alertas).
- A aplicação **grava** com `INSERT/UPDATE/MERGE` simples, e usa **procedures** quando a operação tem várias etapas que precisam acontecer juntas (por exemplo, agendar com checagem de conflito de horário).
- Os **triggers** fazem o que ninguém pode esquecer: abrir o prontuário, marcar o agendamento como realizado, recusar datas impossíveis e registrar a auditoria.

## Convenções de nomes (padrão do projeto)

| Objeto | Padrão | Exemplo |
|---|---|---|
| Tabela | `schema.substantivo_singular` | `clinico.triagem_neonatal` |
| Chave primária | `<tabela>_id` | `crianca_id` |
| Constraint PK | `pk_<tabela>` | `pk_crianca` |
| Constraint FK | `fk_<filha>_<mãe>` | `fk_crianca_gestacao` |
| Único | `uq_<tabela>_<coluna>` | `uq_prontuario_numero` |
| CHECK | `ck_<tabela>_<regra>` | `ck_parto_cesarea` |
| Índice | `ix_<tabela>_<coluna>` | `ix_agendamento_data` |
| View | `vw_…` · Procedure `sp_…` · Função `fn_…` · Trigger `trg_…` | |

Nomes de constraint são importantes: quando o banco recusa algo, a mensagem traz o nome (ex.: `ck_parto_cesarea`) e o backend traduz para *"Informe o motivo da cesárea."* (`backend/src/middlewares/errorHandler.js`).

## Por que o modelo tem esse formato (as 5 decisões principais)

1. **A gestação é o eixo.** Mãe → gestação → filhos. A criança aponta para a gestação, não para a mãe, e assim gêmeos dividem a **mesma** gestação e o **mesmo** parto sem repetir dados.
2. **Parto é da gestação, nascimento é do bebê.** Gêmeos têm 1 parto e 2 nascimentos (cada um com seu Apgar e peso).
3. **Grades viram linhas.** O quadro de sorologias do papel (4 agravos × 3 trimestres) viraria 12 colunas repetidas. Aqui cada célula é **uma linha** em `sorologia_prenatal`. O mesmo vale para os sinais de alerta, os setores de internação e os lados (olho/ouvido D/E).
4. **Nada calculável é guardado.** Idade, AIG/PIG/GIG, "cuidado especial" e o resultado do coraçãozinho são **calculados** por funções/views. Guardar geraria dados que podem ficar desatualizados.
5. **Excluir quase nunca é apagar.** Criança é **inativada** (`ativo = 0` + motivo), agendamento é **cancelado** (`status`). O `DELETE` físico existe só para cadastro duplicado/teste, só para a gestão, e a integridade referencial bloqueia o que tiver histórico.

## Como o banco conversa com a aplicação

```
Tela (HTML/JS) ──fetch──► API Node (Express)
                            routes → controllers → services → repositories ──SQL──► SQL Server
                                                                  ▲
                                         todo o SQL da aplicação fica aqui (T-SQL com @parâmetros)
```

- Todo SQL usa **parâmetros** (`@nome`), nunca concatenação de texto: isso evita **SQL Injection**.
- Antes de gravar, a API executa `sp_set_session_context 'usuario_id'`. É assim que o trigger de auditoria sabe **quem** fez a alteração, mesmo com todos usando o mesmo login `app_caderneta`.
- A tela de **Relatórios** mostra o SQL de cada relatório ("Ver SQL"), útil na apresentação.
