# 7. Problemas e soluções: conectar ao SQL Server da VM

Registro dos erros encontrados ao instalar o SQL Server 2022 na VM (VirtualBox + Ubuntu Server 22.04) e conectar pelo SSMS no Windows, com a causa e a solução de cada um. Complementa o [guia de instalação](06-guia-vm-sqlserver-dbeaver.md).

## Resumo rápido

| # | Sintoma | Causa | Solução |
|---|---|---|---|
| 1 | SSMS conecta no `.` com Autenticação do Windows | Campos padrão apontam para o SQL Server do próprio Windows | Usar `localhost,1433` e Autenticação do SQL Server |
| 2 | Erro 1225: "O computador remoto recusou a conexão de rede" | Nada escutando na porta 1433 (VM desligada, sem redirecionamento ou SQL Server não instalado) | Ligar a VM, criar o redirecionamento de porta, instalar o SQL Server |
| 3 | `Test-NetConnection` com `TcpTestSucceeded : False` | Mesmo problema do item 2, visto pelo PowerShell | Redirecionamento de porta NAT `1433 → 1433` |
| 4 | `gpg: can't create '/urs/share/keyrings/...'` | Erro de digitação: `urs` em vez de `usr` | Corrigir o caminho para `/usr/share/keyrings/` |
| 5 | `NO_PUBKEY EB3E94ADBE1229CF` / "repository is not signed" | O arquivo `.list` da Microsoft não indica a chave (`signed-by`) | Copiar a chave para `/etc/apt/trusted.gpg.d/` |
| 6 | `E: Unable to locate package mssql-server` | Consequência dos itens 4/5, ou nome digitado errado (`msssql-server`) | Corrigir chave/repositório e digitar `mssql-server` |
| 7 | `sudo: /opt/mssql/bin/mssql-conf: command not found` | O SQL Server ainda não foi instalado | Instalar o pacote antes de rodar o `setup` |
| 8 | Dúvida: "de onde vem o usuário `sa`?" | — | Login administrador padrão do SQL Server |

---

## 1. Tela de conexão do SSMS com valores padrão

**Sintoma.** A janela *Conectar* abre com **Nome do Servidor** `.` e **Autenticação do Windows**.

**Causa.** `.` significa "SQL Server deste computador (Windows)". A VM é outra máquina, com Linux, onde não existe usuário do Windows.

**Solução.** Preencher assim:

| Campo | Valor |
|---|---|
| Nome do Servidor | `localhost,1433` (NAT) ou `IP_DA_VM,1433` (host-only) |
| Autenticação | Autenticação do SQL Server |
| Nome do Usuário | `sa` |
| Senha | a senha definida no `mssql-conf setup` |
| Criptografar | Opcional |
| Certificado do Servidor de Confiança | marcado |

> Atenção: no SQL Server a porta vem depois de **vírgula** (`localhost,1433`), não de dois-pontos.

## 2. Erro 1225: conexão recusada

**Mensagem.**

```
Erro de rede ou específico à instância ao estabelecer conexão com o SQL Server.
(provider: Provedor de TCP, error: 0 - O computador remoto recusou a conexão de rede.)
(Microsoft SQL Server, Erro: 1225)
```

**Causa.** O erro acontece **antes** do login: nenhum programa está escutando na porta 1433 do endereço informado. Usuário e senha nem chegam a ser testados. Causas possíveis:

- a VM está desligada;
- não existe redirecionamento de porta no VirtualBox;
- o SQL Server não está instalado ou o serviço está parado na VM.

**Solução.** Testar a rede antes de mexer no SSMS (item 3) e conferir o serviço na VM:

```bash
systemctl status mssql-server --no-pager   # tem que mostrar "active (running)"
```

## 3. Teste da porta pelo PowerShell

**Como testar (no Windows):**

```powershell
Test-NetConnection localhost -Port 1433
```

**Resultado com problema:**

```
AVISO: TCP connect to (127.0.0.1 : 1433) failed
TcpTestSucceeded : False
```

**Solução: redirecionamento de porta (rede NAT).**

1. Com a VM desligada: VirtualBox → selecionar a VM → **Configurações**.
2. **Rede → Adaptador 1** → *Conectado a: NAT*.
3. **Avançado → Redirecionamento de Portas → +**:

| Nome | Protocolo | IP do Anfitrião | Porta do Anfitrião | IP do Convidado | Porta do Convidado |
|---|---|---|---|---|---|
| sqlserver | TCP | (vazio) | 1433 | (vazio) | 1433 |

4. Ligar a VM e repetir o teste. O esperado é `TcpTestSucceeded : True`.

> Se o Windows já tiver um SQL Server próprio usando a 1433, use **1434** na porta do anfitrião e conecte com `localhost,1434`.

> O teste só dá `True` quando o SQL Server já está instalado e rodando na VM. Com o redirecionamento certo e o serviço parado, continua `False`.

## 4. Erro de digitação no caminho da chave

**Mensagem.**

```
gpg: can't create '/urs/share/keyrings/microsoft-prod.gpg': No such file or directory
gpg: no valid OpenPGP data found.
curl: (23) Failed writing body
```

**Causa.** Foi digitado `/urs/` em vez de `/usr/`. A pasta não existe, a chave não é salva e todos os passos seguintes falham em cascata.

**Solução.** Comando correto:

```bash
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
```

Se der certo, não aparece nenhuma mensagem.

## 5. Chave pública não encontrada (NO_PUBKEY)

**Mensagem no `sudo apt-get update`.**

```
Err:5 https://packages.microsoft.com/ubuntu/22.04/mssql-server-2022 jammy InRelease
  The following signatures couldn't be verified because the public key is not available: NO_PUBKEY EB3E94ADBE1229CF
E: The repository '.../mssql-server-2022 jammy InRelease' is not signed.
```

**Causa.** O arquivo baixado da Microsoft (`/etc/apt/sources.list.d/mssql-server-2022.list`) contém só:

```
deb [arch=amd64,arm64,armhf] https://packages.microsoft.com/ubuntu/22.04/mssql-server-2022 jammy main
```

Ele **não** diz onde está a chave (`signed-by=`). Por isso o `apt` ignora a chave salva em `/usr/share/keyrings/` e recusa o repositório.

**Solução.** Colocar a chave na pasta que o `apt` lê automaticamente:

```bash
sudo cp /usr/share/keyrings/microsoft-prod.gpg /etc/apt/trusted.gpg.d/microsoft-prod.gpg
sudo apt-get update
```

O `update` deve terminar sem `Err`, sem `NO_PUBKEY` e com uma linha como `Get:6 .../mssql-server-2022 jammy/main amd64 Packages`.

## 6. Pacote não encontrado

**Mensagem.**

```
E: Unable to locate package mssql-server
```

**Causas.**

- O repositório da Microsoft não foi aceito (itens 4 e 5).
- Nome digitado errado. Aconteceu com `msssql-server` (três "s") e com `apt-ger` em vez de `apt-get`.

**Solução.** Depois de corrigir a chave:

```bash
sudo apt-get install -y mssql-server
```

## 7. `mssql-conf: command not found`

**Mensagem.**

```
sudo: /opt/mssql/bin/mssql-conf: command not found
```

**Causa.** O `mssql-conf` faz parte do pacote `mssql-server`. Enquanto a instalação do item 6 não der certo, esse arquivo não existe. Não é um erro do `setup`, é consequência dos erros anteriores.

**Solução.** Instalar o pacote e só então rodar:

```bash
sudo /opt/mssql/bin/mssql-conf setup
```

- Edição: **2 (Developer)**.
- Licença: `Yes`.
- Senha do `sa`: 8 ou mais caracteres, com maiúscula, minúscula, número e símbolo.

Outros erros possíveis nesta etapa:

- **Pouca memória** (mensagem citando 2000 MB): aumentar a RAM da VM para 4 GB em *Configurações → Sistema*.
- **Senha recusada**: não atende à política de complexidade.

## 8. O que é o usuário `sa`

- `sa` = *system administrator*. É o login administrador que **todo** SQL Server cria na instalação.
- O nome é sempre `sa`. A senha é a definida no `mssql-conf setup` (*"Enter the SQL Server system administrator password"*).
- **Não** é o usuário do Ubuntu (ex.: `saudesigitalvm`), que serve só para entrar na VM.
- No projeto, o `sa` é usado só para criar o banco e rodar os scripts. A aplicação Node conecta com o login **`app_caderneta`**, criado pelo script `05_dcl`.

---

## Sequência correta de instalação (resumo)

```bash
# Na VM (Ubuntu 22.04)
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
sudo cp /usr/share/keyrings/microsoft-prod.gpg /etc/apt/trusted.gpg.d/microsoft-prod.gpg
curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list
sudo apt-get update
sudo apt-get install -y mssql-server
sudo /opt/mssql/bin/mssql-conf setup
systemctl status mssql-server --no-pager
sudo ufw allow 1433/tcp
```

```powershell
# No Windows
Test-NetConnection localhost -Port 1433   # esperado: TcpTestSucceeded : True
```

Depois: SSMS → `localhost,1433` → Autenticação do SQL Server → `sa` → senha → **Conectar**.

## Lições aprendidas

1. **Ler a primeira mensagem de erro.** Os erros 6 e 7 eram só consequência do erro 4. Corrigir o primeiro resolveu a cadeia.
2. **Testar a rede antes do login.** `Test-NetConnection` separa problema de rede (erro 1225) de problema de usuário/senha.
3. **Cuidado com comandos longos digitados à mão.** `urs`, `msssql` e `apt-ger` causaram metade dos erros. Conectar por SSH (redirecionando `2222 → 22`) permite colar os comandos do Windows.
4. **Cada sistema tem seu usuário.** Usuário do Windows, do Ubuntu e do SQL Server (`sa`, `app_caderneta`) são coisas diferentes.
