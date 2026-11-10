# 7. Arquitetura da aplicação

Mesma organização em camadas do protótipo PEC APS (branch `test/roteiro-manual-v3`), **sem blockchain e sem MongoDB**: o único banco é o SQL Server.

```
CadernetaDigital_A3/
├── database/                 TODO o SQL do projeto, um assunto por arquivo
│   ├── 00_reset/             apagar o banco (opcional)
│   ├── 01_ddl/               CREATE DATABASE, SCHEMA, TABLE, INDEX, ALTER TABLE, DROP TABLE IF EXISTS
│   ├── 02_programabilidade/  funções, views, procedures, triggers
│   ├── 03_dml/               INSERT (massa de teste), UPDATE e DELETE de exemplo
│   ├── 04_dql/               consultas operacionais, gerenciais e avançadas
│   ├── 05_dcl/               logins, users, roles, GRANT/DENY
│   ├── ferramentas/          gerador do dicionário de dados
│   └── executar_tudo.sql     roda tudo pelo sqlcmd/SSMS (modo SQLCMD)
├── backend/
│   ├── scripts/db-setup.js   executa os .sql em ordem (npm run db:setup)
│   └── src/
│       ├── app.js            servidor Express (serve também o frontend)
│       ├── config/           db.js (conexão mssql, transação, SESSION_CONTEXT) · permissoes.js
│       ├── middlewares/      auth.js (JWT + perfil) · errorHandler.js (erros do SQL Server → mensagens)
│       ├── routes/           index.js: mapa da API
│       ├── controllers/      recebe HTTP, chama o service, devolve JSON
│       ├── services/         regras de negócio + transações
│       ├── repositories/     ★ todo o SQL da aplicação (T-SQL parametrizado)
│       └── utils/            validações
├── frontend/
│   ├── pages/                login, inicio, criancas, caderneta, agenda, profissionais, relatorios
│   └── assets/               css/app.css · js/app.js (comum) · js/caderneta.js
└── docs/                     esta documentação
```

## Caminho de uma requisição (exemplo: agendar)

```
agenda.html  ──POST /api/agendamentos──►  routes/index.js
                                           ├─ autenticar (JWT válido?)
                                           └─ exigir('agenda.gerenciar') (perfil pode?)
                                         controllers/agendaController.agendar
                                         services/atendimentoService.agendar   → valida campos obrigatórios
                                         config/db.transacao(usuario)           → BEGIN TRAN + sp_set_session_context
                                         repositories/agendaRepository.agendar  → EXEC atendimento.sp_agendar_consulta ...
SQL Server: procedure checa regras → INSERT → trigger de auditoria grava o log → COMMIT
erro? THROW 50013 'O profissional já tem um atendimento nesse horário.' → errorHandler → HTTP 422 → toast na tela
```

## Onde está o SQL de cada operação do CRUD (edital 2.4)

| Operação | Tela | Repository | SQL usado |
|---|---|---|---|
| **Read** médicos/profissionais | Profissionais | `profissionalRepository.listar` | SELECT com JOIN, `STRING_AGG`, filtros opcionais, `EXISTS` |
| **Read** consultas | Agenda / Caderneta | `agendaRepository.listar`, `cadernetaRepository.carregar` | views `vw_agenda_detalhada`, `vw_linha_tempo_crianca` |
| **Read** prontuário | Caderneta | `cadernetaRepository.carregar` | 17 SELECTs num único comando |
| **Create** paciente | Crianças | `gestanteRepository.inserir`, `criancaRepository.inserir` | `INSERT ... OUTPUT`, `SCOPE_IDENTITY()` em transação |
| **Create** agendamento | Agenda | `agendaRepository.agendar` | `EXEC sp_agendar_consulta ... OUTPUT` |
| **Update** seções da caderneta | Caderneta | `cadernetaRepository.salvar*` | `MERGE` (upsert) + `OPENJSON` |
| **Delete lógico** agendamento | Agenda | `agendaRepository.cancelar` | `EXEC sp_cancelar_agendamento` |
| **Delete físico** agendamento | Agenda (gestão) | `agendaRepository.excluir` | `DELETE ... OUTPUT DELETED ... WHERE status IN (...)` |
| **Delete lógico/físico** criança | Crianças | `criancaRepository.inativar/excluirFisico` | `EXEC sp_inativar_crianca` / `DELETE` |

## Ergonomia do redesenho (o que mudou em relação ao papel)

| Problema relatado | Solução na tela |
|---|---|
| Dezenas de campos | campos condicionais: "Qual risco?" só aparece se "Gravidez de risco = Sim"; motivo da cesárea só se cesárea etc. |
| Muitas perguntas Sim/Não | botões segmentados de 1 toque; botão **"Nenhum sinal de alerta"** responde as 8 perguntas de uma vez |
| Cálculos de cabeça | adequação peso/IG, % de perda de peso desde o nascimento, resultado do coraçãozinho e alertas de risco calculados na hora |
| Interrupções (cuidar do bebê) | **rascunho automático** no aparelho: ao voltar, o formulário está como foi deixado |
| Internet instável | se a rede cair ao salvar, o registro vai para uma **fila** no aparelho e é enviado sozinho quando a conexão volta (indicador no menu) |
| Saber o que falta | marcadores coloridos nas abas da caderneta e painel "Início" com triagens atrasadas, consultas da 1ª semana pendentes e crianças em cuidado especial |
| Uso em tablet/celular | layout responsivo, alvos de toque ≥ 44 px, teclado numérico nos campos de medida |
