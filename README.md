# Caderneta Digital da Criança · A3 Banco de Dados

Projeto Integrador de Banco de Dados (UNIFACS, 2026.2). Cenário **Clínica SaúdeDigital**, contexto **redesenho de atendimento**: digitalização da Caderneta da Criança (pré-natal, parto, nascimento, internação neonatal, alta, triagens neonatais e consulta da 1ª semana) para uma rede municipal de saúde.

- **Banco:** Microsoft SQL Server (T-SQL) em VM VirtualBox, com 7 schemas, 33 tabelas, 5 views, 4 funções, 5 procedures e 9 triggers
- **Backend:** Node.js + Express em camadas (routes → controllers → services → repositories); todo o SQL fica nos repositories
- **Frontend:** HTML, CSS e JavaScript puros, com o fluxo de preenchimento redesenhado

![Tela inicial](docs/img/tela-inicio.png)

## Começo rápido

```bash
# 1. SQL Server rodando na VM (veja docs/06-guia-vm-sqlserver-dbeaver.md)
cd backend
npm install
cp .env.example .env        # Windows: copy .env.example .env  → ajuste DB_SERVER e DB_ADMIN_PASSWORD
npm run db:setup            # cria banco, tabelas, objetos, dados de teste e permissões
npm start                   # http://localhost:3000
```

O SQL Server pode estar em uma VM ou em uma instalação local já configurada. Se a porta 3000 estiver ocupada, execute `PORT=3002 npm start` no diretório `backend` e acesse `http://localhost:3002`. No Windows, configure a variável conforme o terminal utilizado.

Acesse `/api/health` para verificar a conexão da API com o banco. `npm run check` carrega os módulos e lista as rotas sem acessar o banco; `node --test` executa os testes disponíveis. Esses testes não substituem a validação completa dos fluxos com SQL Server.

**Dados existentes:** não use `npm run db:reset` se precisar preservá-los. O `db:setup` também remove e recria tabelas; use-o somente em uma base descartável ou nova, após conferir a configuração e os scripts. Nunca compartilhe o arquivo `backend/.env` ou credenciais reais.

Usuários de teste (senha `caderneta123`): `recepcao@`, `enfermeira@`, `tecnica@`, `medico@`, `gestor@caderneta.local`.

## Estrutura

```
database/   scripts SQL separados por tipo: DDL, programabilidade, DML, DQL, DCL
backend/    API Node.js (Express + mssql)
frontend/   telas HTML/CSS/JS
docs/       arquitetura do banco, DER, normalização 3FN, dicionário, guia da VM, roteiro
```

Comece pela [documentação](docs/README.md).

## Entregas do edital → onde estão

| Entrega | Local |
|---|---|
| DER em alta resolução | `docs/img/der.svg`, `docs/02-der.md` |
| Memorial de normalização (3FN) | `docs/03-normalizacao-3fn.md` |
| Dicionário de dados | `docs/04-dicionario-de-dados.md` |
| Requisitos e regras de negócio | `docs/05-requisitos-e-regras-de-negocio.md` |
| Scripts SQL (DDL, DML, DQL) comentados | `database/` |
| Código da aplicação comentado | `backend/src`, `frontend/` |
| Instruções de execução | `docs/06-guia-vm-sqlserver-dbeaver.md` |

> Dados fictícios. Protótipo acadêmico, sem integração oficial com o SUS.

## Ambiente em containers para demonstração

O arquivo `compose.isolado.yml` define uma rede Docker interna, um SQL Server em volume próprio e uma aplicação sem diretórios da máquina montados, executada como usuário não privilegiado, com sistema de arquivos somente leitura. Não usa o SQL Server instalado no computador. O Docker compartilha o kernel do computador: não é uma barreira equivalente a uma VM, e a rede interna não garante proteção absoluta contra acesso ao host. Não use dados reais nem trate este protótipo como ambiente de produção.

Requisitos: Docker com Compose, acesso à internet para baixar imagens e dependências, e memória suficiente para SQL Server. Na raiz do projeto, crie `.env.isolado` (não versionado) com uma senha forte para `MSSQL_SA_PASSWORD` e um valor aleatório para `JWT_SECRET`, por exemplo:

```bash
umask 077
set -C  # impede sobrescrever um arquivo existente
printf 'MSSQL_SA_PASSWORD=Aa1!%s\nJWT_SECRET=%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > .env.isolado
set +C
```

Guarde esse arquivo: a senha do SQL Server é definida na primeira criação do volume. Em seguida:

```bash
docker compose --env-file .env.isolado -f compose.isolado.yml up -d --build
```

**Somente na primeira instalação, com volume vazio**, carregue o banco de demonstração depois que o SQL Server tiver inicializado:

```bash
set -a; . ./.env.isolado; set +a
DB_ADMIN_PASSWORD="$MSSQL_SA_PASSWORD" docker compose --env-file .env.isolado -f compose.isolado.yml run --rm -e DB_ADMIN_USER=sa -e DB_ADMIN_PASSWORD app npm run db:setup
unset DB_ADMIN_PASSWORD MSSQL_SA_PASSWORD JWT_SECRET
```

**Atenção:** o setup remove e recria tabelas; não o repita em um volume que contenha dados a preservar. `docker compose --env-file .env.isolado -f compose.isolado.yml down` para os containers e mantém o volume. A opção `-v` também apaga os dados do volume.

O Compose solicita publicação em `127.0.0.1:3003`, mas isso depende da configuração do Docker. Neste computador, a publicação na rede interna não ficou disponível; dentro do container, a saúde foi verificada com:

```bash
docker compose --env-file .env.isolado -f compose.isolado.yml exec -T app node -e "fetch('http://127.0.0.1:3000/api/health').then(async r => console.log(r.status, await r.text()))"
```

As senhas de usuários da aplicação e os dados de exemplo são públicos e exclusivos para demonstração. A API e o banco não foram configurados para dados reais ou exposição pública.
