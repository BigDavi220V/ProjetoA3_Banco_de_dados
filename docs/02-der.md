# 2. Diagrama Entidade-Relacionamento (DER)

![DER](img/der.png)

Versão vetorial (alta resolução, para o relatório): [`img/der.svg`](img/der.svg). Fonte editável: [`der.mmd`](der.mmd) (Mermaid; abre no VS Code, no GitHub ou em mermaid.live).

> Para não poluir o desenho, só as entidades principais mostram atributos. A lista completa de colunas está no [dicionário de dados](04-dicionario-de-dados.md). O DBeaver também gera o diagrama físico a partir do banco: botão direito no banco → **View Diagram**.

## Cardinalidades (leitura em português)

| Relacionamento | Cardinalidade | Como está implementado |
|---|---|---|
| Gestante tem gestações | 1 : N | FK `gestacao.gestante_id` |
| Gestante tem telefones (multivalorado) | 1 : N | tabela `gestante_telefone` |
| Gestação gera crianças (gêmeos = 2) | 1 : 1..N | FK `crianca.gestacao_id` (NOT NULL) |
| Gestação termina em parto | 1 : 0..1 | FK `parto.gestacao_id` + **UNIQUE** |
| Gestação × agravo × trimestre → sorologia | N : N (com atributo) | PK composta `(gestacao_id, agravo_id, trimestre)` |
| Gestação × vacina (pré-natal) | N : N | PK composta `(gestacao_id, vacina_id)` |
| Criança possui prontuário | 1 : 1 | `prontuario.crianca_id` UNIQUE; criado por trigger |
| Criança tem nascimento | 1 : 0..1 | `nascimento.crianca_id` UNIQUE |
| Criança tem internação neonatal | 1 : 0..1 | `internacao_neonatal.crianca_id` UNIQUE |
| Internação passa por setores | N : N (com dias) | PK composta `(internacao_id, setor_id)` |
| Criança recebe alta da maternidade | 1 : 0..1 | `alta_maternidade.crianca_id` UNIQUE |
| Criança faz triagens (um registro por tipo) | 1 : 0..4 | UNIQUE `(crianca_id, tipo_triagem_id)` |
| Triagem tem resultado por lado | 1 : 0..2 | PK `(triagem_id, lado)` + CHECK lado IN (D,E) |
| Triagem (coraçãozinho) tem aferições | 1 : 0..2 | PK `(triagem_id, numero_afericao)` |
| Profissional × especialidade | N : N | tabela associativa `profissional_especialidade` |
| Profissional lotado em unidade | N : 1 | FK `profissional.unidade_id` |
| Criança tem agendamentos | 1 : N | FK `agendamento.crianca_id` |
| Agendamento vira consulta | 1 : 0..1 | `consulta.agendamento_id` com índice único filtrado |
| Consulta avalia sinais de alerta | N : N (Sim/Não) | PK `(consulta_id, sinal_alerta_id)` |
| Criança recebe vacinas | 1 : N | UNIQUE `(crianca_id, vacina_id, dose)` |
| Profissional acessa como usuário | 1 : 0..1 | `usuario.profissional_id` com índice único filtrado |

## Código-fonte do diagrama

```mermaid
erDiagram
  GESTANTE ||--o{ GESTANTE_TELEFONE : "tem"
  GESTANTE ||--o{ GESTACAO : "tem"
  GESTACAO ||--o{ SOROLOGIA_PRENATAL : "registra"
  AGRAVO ||--o{ SOROLOGIA_PRENATAL : "classifica"
  GESTACAO ||--o{ VACINA_PRENATAL : "registra"
  VACINA ||--o{ VACINA_PRENATAL : "é"
  GESTACAO ||--o| PARTO : "termina em"
  UNIDADE_SAUDE ||--o{ PARTO : "local"
  GESTACAO ||--|{ CRIANCA : "gera"
  CRIANCA ||--|| PRONTUARIO : "possui"
  CRIANCA ||--o| NASCIMENTO : "tem"
  CRIANCA ||--o| INTERNACAO_NEONATAL : "pode ter"
  INTERNACAO_NEONATAL ||--|{ INTERNACAO_SETOR : "passa por"
  SETOR_INTERNACAO ||--o{ INTERNACAO_SETOR : "é"
  CRIANCA ||--o| ALTA_MATERNIDADE : "recebe"
  CRIANCA ||--o{ TRIAGEM_NEONATAL : "faz"
  TIPO_TRIAGEM ||--o{ TRIAGEM_NEONATAL : "é"
  TRIAGEM_NEONATAL ||--o{ TRIAGEM_RESULTADO_LADO : "resulta"
  TRIAGEM_NEONATAL ||--o{ OXIMETRIA_AFERICAO : "afere"
  UNIDADE_SAUDE ||--o{ PROFISSIONAL : "lota"
  CATEGORIA_PROFISSIONAL ||--o{ PROFISSIONAL : "classifica"
  PROFISSIONAL ||--o{ PROFISSIONAL_ESPECIALIDADE : "possui"
  ESPECIALIDADE ||--o{ PROFISSIONAL_ESPECIALIDADE : "habilita"
  CRIANCA ||--o{ AGENDAMENTO : "tem"
  PROFISSIONAL ||--o{ AGENDAMENTO : "atende"
  ESPECIALIDADE ||--o{ AGENDAMENTO : "de"
  AGENDAMENTO ||--o| CONSULTA : "vira"
  CRIANCA ||--o{ CONSULTA : "recebe"
  PROFISSIONAL ||--o{ CONSULTA : "realiza"
  ESPECIALIDADE ||--o{ CONSULTA : "de"
  CONSULTA ||--o{ CONSULTA_SINAL_ALERTA : "avalia"
  SINAL_ALERTA ||--o{ CONSULTA_SINAL_ALERTA : "é"
  CRIANCA ||--o{ VACINA_APLICADA : "recebe"
  VACINA ||--o{ VACINA_APLICADA : "é"
  PERFIL ||--o{ USUARIO : "define"
  PROFISSIONAL ||--o| USUARIO : "acessa como"

  GESTANTE { int gestante_id PK
    nvarchar nome
    char cpf UK
    char cns UK
    date data_nascimento
    varchar tipo_sanguineo }
  GESTACAO { int gestacao_id PK
    int gestante_id FK
    bit fez_prenatal
    tinyint numero_consultas
    varchar tipo_gravidez
    varchar coombs_indireto }
  CRIANCA { int crianca_id PK
    int gestacao_id FK
    nvarchar nome
    char sexo
    date data_nascimento
    char cns UK
    bit ativo }
  NASCIMENTO { int nascimento_id PK
    int crianca_id FK,UK
    tinyint apgar_5min
    tinyint ig_semanas
    smallint peso_g
    varchar coombs_direto }
  PARTO { int parto_id PK
    int gestacao_id FK,UK
    varchar local_tipo
    varchar tipo_parto }
  SOROLOGIA_PRENATAL { int gestacao_id PK,FK
    int agravo_id PK,FK
    tinyint trimestre PK
    varchar resultado }
  TRIAGEM_NEONATAL { int triagem_id PK
    int crianca_id FK
    int tipo_triagem_id FK
    bit realizada
    date data_realizacao }
  PROFISSIONAL { int profissional_id PK
    nvarchar nome
    char cpf UK
    int categoria_id FK
    int unidade_id FK }
  AGENDAMENTO { int agendamento_id PK
    int crianca_id FK
    int profissional_id FK
    datetime2 data_hora
    varchar status }
  CONSULTA { int consulta_id PK
    int crianca_id FK
    int profissional_id FK
    int agendamento_id FK,UK
    varchar tipo_atendimento
    smallint peso_g }

```
