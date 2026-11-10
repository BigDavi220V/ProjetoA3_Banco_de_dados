# 6. Guia de instalação: VirtualBox + SQL Server + DBeaver + aplicação

O edital pede o SGBD **dentro de uma máquina virtual (Oracle VM VirtualBox)** e a inspeção visual por uma ferramenta como o DBeaver. O SGBD deste projeto é o **Microsoft SQL Server** (linguagem T-SQL).

## Visão geral

```
 Seu Windows (host)                                VM VirtualBox (Ubuntu Server)
 ┌──────────────────────────────┐   rede          ┌───────────────────────────┐
 │ Navegador → Node (porta 3000)│ ──────────────► │ SQL Server 2022 (1433)    │
 │ DBeaver / SSMS               │   1433          │ banco CadernetaDigital    │
 └──────────────────────────────┘                 └───────────────────────────┘
```

## Passo 1: criar a VM

1. Instale o **Oracle VirtualBox**.
2. Baixe a ISO do **Ubuntu Server 22.04 LTS** (versão suportada pelo SQL Server 2022).
3. Nova VM: 2 CPUs, **4 GB de RAM** (o SQL Server exige no mínimo 2 GB), disco de 25 GB.
4. **Rede** (escolha uma das duas):
   - **Adaptador 1 = NAT** + *Avançado → Redirecionamento de portas*: regra `TCP host 1433 → convidado 1433`. No `.env` use `DB_SERVER=localhost`.
   - ou **Adaptador 2 = Placa de rede exclusiva de hospedeiro (host-only)**. A VM recebe um IP como `192.168.56.101`; use esse IP no `.env`.
5. Instale o Ubuntu (marque "Install OpenSSH server").

## Passo 2: instalar o SQL Server na VM

Dentro da VM (siga a documentação oficial da Microsoft "Quickstart: Install SQL Server and create a database on Ubuntu", que tem os comandos atualizados):

```bash
# 1) chave e repositório da Microsoft
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list

# 2) instalar
sudo apt-get update
sudo apt-get install -y mssql-server

# 3) configurar: escolha a edição "Developer" ou "Express" (gratuitas) e defina a senha do "sa"
sudo /opt/mssql/bin/mssql-conf setup

# 4) conferir se está rodando e liberar a porta
systemctl status mssql-server --no-pager
sudo ufw allow 1433/tcp
```

> A senha do `sa` precisa ter 8+ caracteres, com maiúscula, minúscula, número e símbolo.
> Fuso horário da VM: `sudo timedatectl set-timezone America/Bahia` (as datas "de hoje" do sistema dependem dele).

## Passo 3: conectar o DBeaver (inspeção visual)

1. DBeaver → **Nova conexão** → **SQL Server**.
2. Host: `localhost` (NAT) ou o IP da VM · Porta `1433` · Database `master` · Usuário `sa`.
3. Aba *Driver properties*: `trustServerCertificate = true` (e `encrypt = false`).
4. **Testar conexão**.

Depois de criar o banco (passo 4): expanda `CadernetaDigital → Schemas` e você verá `cadastro`, `clinico`, `atendimento`... Botão direito no banco → **View Diagram** gera o diagrama físico com as FKs.

> Alternativa: **SQL Server Management Studio (SSMS)** ou **Azure Data Studio**, que conectam do mesmo jeito.

## Passo 4: criar o banco (DDL + DML + DCL)

**Opção A, pelo Node (recomendado):**

```bash
cd backend
npm install
copy .env.example .env      # (no Linux/Mac: cp) e edite DB_SERVER, DB_ADMIN_PASSWORD
npm run db:setup            # roda 01_ddl, 02_programabilidade, 03_dml e 05_dcl em ordem
npm run db:consultas        # (opcional) roda as consultas DQL e mostra quantas linhas cada uma trouxe
```

`npm run db:reset` apaga o banco e recria do zero (bom antes da apresentação).

**Opção B, pelo DBeaver/SSMS:** abra e execute os arquivos **na ordem dos números** (`01_ddl/01…`, `01_ddl/02…`, …, `02_programabilidade/…`, `03_dml/…`, `05_dcl/…`). No DBeaver use *Executar script* (Alt+X). Os arquivos usam `GO` para separar lotes, que o DBeaver e o SSMS entendem.

**Opção C, `sqlcmd` (no terminal da VM ou do Windows), dentro da pasta `database`:**

```bash
sqlcmd -S localhost,1433 -U sa -P "SUA_SENHA" -I -C -i executar_tudo.sql
```

## Passo 5: rodar a aplicação

```bash
cd backend
npm start
```

Abra **http://localhost:3000**. Usuários de teste (senha `caderneta123`):

| Login | Perfil |
|---|---|
| `recepcao@caderneta.local` | Recepção |
| `enfermeira@caderneta.local` | Enfermagem |
| `tecnica@caderneta.local` | Enfermagem (técnica) |
| `medico@caderneta.local` | Médico(a) |
| `gestor@caderneta.local` | Gestão |

A aplicação conecta com o usuário **`app_caderneta`** (criado pelo `05_dcl`), não com o `sa`.

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `Failed to connect ... ESOCKET` | porta 1433 não chega na VM | confira o redirecionamento de porta / IP host-only / `ufw` |
| `Login failed for user 'app_caderneta'` | o script `05_dcl` não rodou ou a senha no `.env` está diferente | rode `npm run db:setup` e confira `DB_PASSWORD` |
| `Login failed for user 'sa'` | autenticação SQL desabilitada (só no Windows) | SSMS → propriedades do servidor → *Security* → "SQL Server and Windows Authentication mode" e reiniciar o serviço |
| `CREATE INDEX failed because ... QUOTED_IDENTIFIER` | rodou pelo `sqlcmd` sem `-I` | use `sqlcmd ... -I` |
| Agenda de "hoje" vazia | fuso da VM diferente | `timedatectl set-timezone America/Bahia` e `npm run db:reset` |
| Mensagem "Banco de dados indisponível" na tela | VM desligada | ligue a VM; a API reconecta sozinha |
