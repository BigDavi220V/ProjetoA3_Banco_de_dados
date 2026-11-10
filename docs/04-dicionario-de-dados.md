# 4. Dicionário de dados

> Gerado automaticamente a partir de `database/01_ddl` por `database/ferramentas/gerar_dicionario.py`.
> Legenda: **PK** chave primária · **FK** chave estrangeira · **UQ** único · **CK** regra CHECK · **DF** valor padrão.

## `dominio.especialidade`

Especialidades em que os profissionais atendem (Pediatria, Neonatologia...).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `especialidade_id` | INT | não | PK | IDENTITY |  |
| `nome` | NVARCHAR(80) | não | UQ |  |  |
| `descricao` | NVARCHAR(255) | sim |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_especialidade PRIMARY KEY (especialidade_id)
CONSTRAINT uq_especialidade_nome UNIQUE (nome)
```
</details>

## `dominio.categoria_profissional`

Categoria do profissional e o conselho que a regula (CRM, COREN, CRFa).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `categoria_id` | INT | não | PK | IDENTITY |  |
| `nome` | NVARCHAR(60) | não | UQ |  |  |
| `conselho` | VARCHAR(6) | não | CK |  |  |
| `pode_assinar_clinico` | BIT | não |  | DEFAULT 1 |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_categoria_profissional PRIMARY KEY (categoria_id)
CONSTRAINT uq_categoria_nome UNIQUE (nome)
CONSTRAINT ck_categoria_conselho CHECK (conselho IN ('CRM','COREN','CRFa','NENHUM'))
```
</details>

## `dominio.agravo`

Agravos pesquisados nas sorologias do pré-natal, com código CID-10.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `agravo_id` | INT | não | PK | IDENTITY |  |
| `cid10` | VARCHAR(6) | não | CK, UQ |  |  |
| `nome` | NVARCHAR(100) | não |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_agravo PRIMARY KEY (agravo_id)
CONSTRAINT uq_agravo_cid10 UNIQUE (cid10)
CONSTRAINT ck_agravo_cid10 CHECK (cid10 LIKE '[A-Z][0-9][0-9]%')
```
</details>

## `dominio.vacina`

Vacinas da gestante e do recém-nascido.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `vacina_id` | INT | não | PK | IDENTITY |  |
| `sigla` | VARCHAR(15) | não | UQ |  |  |
| `nome` | NVARCHAR(100) | não |  |  |  |
| `publico_alvo` | VARCHAR(8) | não | CK |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_vacina PRIMARY KEY (vacina_id)
CONSTRAINT uq_vacina_sigla UNIQUE (sigla)
CONSTRAINT ck_vacina_publico CHECK (publico_alvo IN ('GESTANTE','CRIANCA','AMBOS'))
```
</details>

## `dominio.tipo_triagem`

Os quatro testes da triagem neonatal e seus prazos.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `tipo_triagem_id` | INT | não | PK | IDENTITY |  |
| `codigo` | VARCHAR(20) | não | UQ |  |  |
| `nome` | NVARCHAR(80) | não |  |  |  |
| `nome_popular` | NVARCHAR(40) | não |  |  |  |
| `orientacao_prazo` | NVARCHAR(200) | não |  |  |  |
| `prazo_max_dias` | SMALLINT | não | CK |  | após isso a triagem é considerada atrasada |
| `avalia_lateralidade` | BIT | não |  |  | 1 = resultado por lado (olho/ouvido D e E) |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_tipo_triagem PRIMARY KEY (tipo_triagem_id)
CONSTRAINT uq_tipo_triagem_codigo UNIQUE (codigo)
CONSTRAINT ck_tipo_triagem_prazo CHECK (prazo_max_dias BETWEEN 1 AND 60)
```
</details>

## `dominio.sinal_alerta`

Sinais de alerta avaliados na consulta da 1ª semana.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `sinal_alerta_id` | INT | não | PK | IDENTITY |  |
| `nome` | NVARCHAR(80) | não | UQ |  |  |
| `criterio` | NVARCHAR(120) | sim |  |  |  |
| `ordem_exibicao` | TINYINT | não |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_sinal_alerta PRIMARY KEY (sinal_alerta_id)
CONSTRAINT uq_sinal_alerta_nome UNIQUE (nome)
```
</details>

## `dominio.setor_internacao`

Setores de internação neonatal (UTIN, UCINCo, UCINCa, Alojamento Conjunto).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `setor_id` | INT | não | PK | IDENTITY |  |
| `sigla` | VARCHAR(10) | não | UQ |  |  |
| `nome` | NVARCHAR(100) | não |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_setor_internacao PRIMARY KEY (setor_id)
CONSTRAINT uq_setor_internacao_sigla UNIQUE (sigla)
```
</details>

## `dominio.referencia_peso_ig`

Percentis 10 e 90 de peso por idade gestacional e sexo (classificação AIG/PIG/GIG).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `ig_semanas` | TINYINT | não | CK, PK |  |  |
| `sexo` | CHAR(1) | não | CK, PK |  |  |
| `p10_g` | SMALLINT | não | CK |  |  |
| `p90_g` | SMALLINT | não | CK |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_referencia_peso_ig PRIMARY KEY (ig_semanas, sexo)
CONSTRAINT ck_ref_sexo CHECK (sexo IN ('M','F'))
CONSTRAINT ck_ref_faixa CHECK (p10_g < p90_g)
CONSTRAINT ck_ref_semanas CHECK (ig_semanas BETWEEN 22 AND 44)
```
</details>

## `cadastro.unidade_saude`

Unidades da rede: UBS/USF, maternidades, centro de parto e hospital.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `unidade_id` | INT | não | PK | IDENTITY |  |
| `cnes` | CHAR(7) | não | CK, UQ |  | Cadastro Nacional de Estabelecimentos de Saúde |
| `nome` | NVARCHAR(120) | não |  |  |  |
| `tipo` | VARCHAR(20) | não | CK |  |  |
| `logradouro` | NVARCHAR(120) | não |  |  |  |
| `numero` | NVARCHAR(10) | sim |  |  |  |
| `bairro` | NVARCHAR(60) | não |  |  |  |
| `municipio` | NVARCHAR(60) | não |  |  |  |
| `uf` | CHAR(2) | não | CK |  |  |
| `telefone` | VARCHAR(11) | sim |  |  |  |
| `ativo` | BIT | não |  | DEFAULT 1 |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_unidade_saude PRIMARY KEY (unidade_id)
CONSTRAINT uq_unidade_cnes UNIQUE (cnes)
CONSTRAINT ck_unidade_cnes CHECK (cnes NOT LIKE '%[^0-9]%')
CONSTRAINT ck_unidade_tipo CHECK (tipo IN ('UBS','USF','MATERNIDADE','CENTRO_PARTO_NORMAL','HOSPITAL'))
CONSTRAINT ck_unidade_uf CHECK (uf LIKE '[A-Z][A-Z]')
```
</details>

## `cadastro.profissional`

Profissionais de saúde e administrativos (edital: entidade Médico, generalizada).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `profissional_id` | INT | não | PK | IDENTITY |  |
| `nome` | NVARCHAR(150) | não |  |  |  |
| `cpf` | CHAR(11) | não | CK, UQ |  |  |
| `categoria_id` | INT | não | FK → dominio.categoria_profissional (categoria_id) |  |  |
| `registro_conselho` | VARCHAR(15) | sim | CK |  | nº CRM / COREN / CRFa |
| `uf_conselho` | CHAR(2) | sim | CK |  |  |
| `unidade_id` | INT | não | FK → cadastro.unidade_saude (unidade_id) |  | lotação principal |
| `email` | VARCHAR(120) | sim | CK |  |  |
| `ativo` | BIT | não |  | DEFAULT 1 |  |
| `criado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_profissional PRIMARY KEY (profissional_id)
CONSTRAINT uq_profissional_cpf UNIQUE (cpf)
CONSTRAINT fk_profissional_categoria FOREIGN KEY (categoria_id) REFERENCES dominio.categoria_profissional (categoria_id)
CONSTRAINT fk_profissional_unidade FOREIGN KEY (unidade_id) REFERENCES cadastro.unidade_saude (unidade_id)
CONSTRAINT ck_profissional_cpf CHECK (cpf NOT LIKE '%[^0-9]%')
CONSTRAINT ck_profissional_conselho CHECK ((registro_conselho IS NULL AND uf_conselho IS NULL)
CONSTRAINT ck_profissional_email CHECK (email IS NULL OR email LIKE '%_@_%._%')
```
</details>

## `cadastro.profissional_especialidade`

Associativa N:N entre profissional e especialidade.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `profissional_id` | INT | não | FK → cadastro.profissional (profissional_id), PK |  |  |
| `especialidade_id` | INT | não | FK → dominio.especialidade (especialidade_id), PK |  |  |
| `data_titulo` | DATE | sim |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_profissional_especialidade PRIMARY KEY (profissional_id, especialidade_id)
CONSTRAINT fk_profesp_profissional FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id) ON DELETE CASCADE
CONSTRAINT fk_profesp_especialidade FOREIGN KEY (especialidade_id) REFERENCES dominio.especialidade (especialidade_id)
```
</details>

## `cadastro.gestante`

Mãe / gestante. Endereço (atributo composto) decomposto em colunas.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `gestante_id` | INT | não | PK | IDENTITY |  |
| `nome` | NVARCHAR(150) | não |  |  |  |
| `cpf` | CHAR(11) | sim | CK |  |  |
| `cns` | CHAR(15) | sim | CK |  | Cartão Nacional de Saúde |
| `data_nascimento` | DATE | não | CK |  |  |
| `tipo_sanguineo` | VARCHAR(2) | sim | CK |  |  |
| `fator_rh` | CHAR(1) | sim | CK |  |  |
| `logradouro` | NVARCHAR(120) | sim |  |  |  |
| `numero` | NVARCHAR(10) | sim |  |  |  |
| `complemento` | NVARCHAR(60) | sim |  |  |  |
| `bairro` | NVARCHAR(60) | sim |  |  |  |
| `municipio` | NVARCHAR(60) | não |  | DEFAULT N'Salvador' |  |
| `uf` | CHAR(2) | não |  | DEFAULT 'BA' |  |
| `cep` | CHAR(8) | sim | CK |  |  |
| `unidade_referencia_id` | INT | sim | FK → cadastro.unidade_saude (unidade_id) |  |  |
| `criado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_gestante PRIMARY KEY (gestante_id)
CONSTRAINT fk_gestante_unidade FOREIGN KEY (unidade_referencia_id) REFERENCES cadastro.unidade_saude (unidade_id)
CONSTRAINT ck_gestante_documento CHECK (cpf IS NOT NULL OR cns IS NOT NULL)
CONSTRAINT ck_gestante_cpf CHECK (cpf IS NULL OR cpf NOT LIKE '%[^0-9]%')
CONSTRAINT ck_gestante_cns CHECK (cns IS NULL OR cns NOT LIKE '%[^0-9]%')
CONSTRAINT ck_gestante_tipo_sang CHECK (tipo_sanguineo IS NULL OR tipo_sanguineo IN ('A','B','AB','O'))
CONSTRAINT ck_gestante_rh CHECK (fator_rh IS NULL OR fator_rh IN ('+','-'))
CONSTRAINT ck_gestante_cep CHECK (cep IS NULL OR cep NOT LIKE '%[^0-9]%')
CONSTRAINT ck_gestante_nascimento CHECK (data_nascimento > '1950-01-01')
```
</details>

## `cadastro.gestante_telefone`

Telefones da gestante (atributo multivalorado normalizado).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `telefone_id` | INT | não | PK | IDENTITY |  |
| `gestante_id` | INT | não | FK → cadastro.gestante (gestante_id), UQ |  |  |
| `ddd` | CHAR(2) | não | CK, UQ |  |  |
| `numero` | VARCHAR(9) | não | CK, UQ |  |  |
| `tipo` | VARCHAR(8) | não | CK | DEFAULT 'CELULAR' |  |
| `whatsapp` | BIT | não |  | DEFAULT 0 |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_gestante_telefone PRIMARY KEY (telefone_id)
CONSTRAINT fk_telefone_gestante FOREIGN KEY (gestante_id) REFERENCES cadastro.gestante (gestante_id) ON DELETE CASCADE
CONSTRAINT uq_telefone_gestante UNIQUE (gestante_id, ddd, numero)
CONSTRAINT ck_telefone_tipo CHECK (tipo IN ('CELULAR','FIXO','RECADO'))
CONSTRAINT ck_telefone_numero CHECK (numero NOT LIKE '%[^0-9]%' AND LEN(numero) BETWEEN 8 AND 9)
CONSTRAINT ck_telefone_ddd CHECK (ddd LIKE '[1-9][0-9]')
```
</details>

## `clinico.gestacao`

Cada gravidez da gestante; eixo que liga mãe, parto e filhos.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `gestacao_id` | INT | não | PK | IDENTITY |  |
| `gestante_id` | INT | não | FK → cadastro.gestante (gestante_id) |  |  |
| `data_registro` | DATE | não |  | DEFAULT CAST(SYSDATETIME() AS DATE) |  |
| `dum` | DATE | sim |  |  | data da última menstruação |
| `planejada` | BIT | sim |  |  | NULL = não informado |
| `fez_prenatal` | BIT | sim |  |  |  |
| `numero_consultas` | TINYINT | sim | CK |  |  |
| `trimestre_inicio` | TINYINT | sim | CK |  |  |
| `tipo_gravidez` | VARCHAR(8) | sim | CK |  |  |
| `gravidez_risco` | BIT | sim | CK |  |  |
| `risco_descricao` | NVARCHAR(200) | sim |  |  |  |
| `coombs_indireto` | VARCHAR(13) | sim | CK |  | exame da MÃE (CI do formulário) |
| `observacao` | NVARCHAR(300) | sim |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_gestacao PRIMARY KEY (gestacao_id)
CONSTRAINT fk_gestacao_gestante FOREIGN KEY (gestante_id) REFERENCES cadastro.gestante (gestante_id)
CONSTRAINT ck_gestacao_consultas CHECK (numero_consultas IS NULL OR numero_consultas BETWEEN 0 AND 40)
CONSTRAINT ck_gestacao_trimestre CHECK (trimestre_inicio IS NULL OR trimestre_inicio BETWEEN 1 AND 3)
CONSTRAINT ck_gestacao_tipo CHECK (tipo_gravidez IS NULL OR tipo_gravidez IN ('UNICA','MULTIPLA'))
CONSTRAINT ck_gestacao_coombs CHECK (coombs_indireto IS NULL OR coombs_indireto IN ('POSITIVO','NEGATIVO','NAO_REALIZADO'))
CONSTRAINT ck_gestacao_prenatal CHECK (fez_prenatal IS NULL OR fez_prenatal = 1
CONSTRAINT ck_gestacao_risco CHECK (ISNULL(gravidez_risco, 0) = 0 OR risco_descricao IS NOT NULL)
```
</details>

## `clinico.sorologia_prenatal`

Uma linha por célula da grade agravo × trimestre do formulário.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `gestacao_id` | INT | não | FK → clinico.gestacao (gestacao_id), PK |  |  |
| `agravo_id` | INT | não | FK → dominio.agravo (agravo_id), PK |  |  |
| `trimestre` | TINYINT | não | CK, PK |  |  |
| `resultado` | VARCHAR(3) | não | CK |  | NR = não realizado, N = normal, ALT = alterado |
| `data_exame` | DATE | sim | CK |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_sorologia_prenatal PRIMARY KEY (gestacao_id, agravo_id, trimestre)
CONSTRAINT fk_sorologia_gestacao FOREIGN KEY (gestacao_id) REFERENCES clinico.gestacao (gestacao_id) ON DELETE CASCADE
CONSTRAINT fk_sorologia_agravo FOREIGN KEY (agravo_id) REFERENCES dominio.agravo (agravo_id)
CONSTRAINT ck_sorologia_trimestre CHECK (trimestre BETWEEN 1 AND 3)
CONSTRAINT ck_sorologia_resultado CHECK (resultado IN ('NR','N','ALT'))
CONSTRAINT ck_sorologia_data CHECK (resultado <> 'NR' OR data_exame IS NULL)
```
</details>

## `clinico.vacina_prenatal`

Vacinas recebidas pela gestante no pré-natal.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `gestacao_id` | INT | não | FK → clinico.gestacao (gestacao_id), PK |  |  |
| `vacina_id` | INT | não | FK → dominio.vacina (vacina_id), PK |  |  |
| `recebeu` | BIT | não |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_vacina_prenatal PRIMARY KEY (gestacao_id, vacina_id)
CONSTRAINT fk_vacina_prenatal_gestacao FOREIGN KEY (gestacao_id) REFERENCES clinico.gestacao (gestacao_id) ON DELETE CASCADE
CONSTRAINT fk_vacina_prenatal_vacina FOREIGN KEY (vacina_id) REFERENCES dominio.vacina (vacina_id)
```
</details>

## `clinico.parto`

Parto da gestação (1:1). Local e tipo de parto.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `parto_id` | INT | não | PK | IDENTITY |  |
| `gestacao_id` | INT | não | FK → clinico.gestacao (gestacao_id), UQ |  |  |
| `data_parto` | DATE | não |  |  |  |
| `local_tipo` | VARCHAR(20) | não | CK |  |  |
| `unidade_id` | INT | sim | FK → cadastro.unidade_saude (unidade_id) |  | maternidade / centro de parto da rede |
| `local_descricao` | NVARCHAR(150) | sim | CK |  | quando é "Outro" ou fora da rede |
| `tipo_parto` | VARCHAR(8) | não | CK |  |  |
| `motivo_cesarea` | NVARCHAR(200) | sim | CK |  |  |
| `teve_acompanhante` | BIT | sim |  |  |  |
| `acompanhante_descricao` | NVARCHAR(100) | sim |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_parto PRIMARY KEY (parto_id)
CONSTRAINT uq_parto_gestacao UNIQUE (gestacao_id)
CONSTRAINT fk_parto_gestacao FOREIGN KEY (gestacao_id) REFERENCES clinico.gestacao (gestacao_id)
CONSTRAINT fk_parto_unidade FOREIGN KEY (unidade_id) REFERENCES cadastro.unidade_saude (unidade_id)
CONSTRAINT ck_parto_local CHECK (local_tipo IN ('HOSPITAL','CENTRO_PARTO_NORMAL','DOMICILIO','OUTRO'))
CONSTRAINT ck_parto_local_outro CHECK (local_tipo <> 'OUTRO' OR local_descricao IS NOT NULL)
CONSTRAINT ck_parto_tipo CHECK (tipo_parto IN ('VAGINAL','CESAREA'))
CONSTRAINT ck_parto_cesarea CHECK (tipo_parto <> 'CESAREA' OR motivo_cesarea IS NOT NULL)
```
</details>

## `cadastro.crianca`

Criança acompanhada pela caderneta (edital: entidade Paciente).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `crianca_id` | INT | não | PK | IDENTITY |  |
| `gestacao_id` | INT | não | FK → clinico.gestacao (gestacao_id) |  |  |
| `nome` | NVARCHAR(150) | não |  |  |  |
| `sexo` | CHAR(1) | não | CK |  |  |
| `data_nascimento` | DATE | não | CK |  |  |
| `cns` | CHAR(15) | sim | CK |  |  |
| `tipo_sanguineo` | VARCHAR(2) | sim | CK |  |  |
| `fator_rh` | CHAR(1) | sim | CK |  |  |
| `unidade_referencia_id` | INT | não | FK → cadastro.unidade_saude (unidade_id) |  | UBS/USF que acompanha a criança |
| `ativo` | BIT | não | CK | DEFAULT 1 |  |
| `inativado_em` | DATETIME | sim | CK |  |  |
| `motivo_inativacao` | NVARCHAR(200) | sim | CK |  |  |
| `criado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_crianca PRIMARY KEY (crianca_id)
CONSTRAINT fk_crianca_gestacao FOREIGN KEY (gestacao_id) REFERENCES clinico.gestacao (gestacao_id)
CONSTRAINT fk_crianca_unidade FOREIGN KEY (unidade_referencia_id) REFERENCES cadastro.unidade_saude (unidade_id)
CONSTRAINT ck_crianca_sexo CHECK (sexo IN ('M','F','I')), -- I = indeterminado
CONSTRAINT ck_crianca_nascimento CHECK (data_nascimento <= CAST(GETDATE() AS DATE))
CONSTRAINT ck_crianca_cns CHECK (cns IS NULL OR cns NOT LIKE '%[^0-9]%')
CONSTRAINT ck_crianca_tipo_sang CHECK (tipo_sanguineo IS NULL OR tipo_sanguineo IN ('A','B','AB','O'))
CONSTRAINT ck_crianca_rh CHECK (fator_rh IS NULL OR fator_rh IN ('+','-'))
CONSTRAINT ck_crianca_inativacao CHECK (ativo = 1 OR (inativado_em IS NOT NULL AND motivo_inativacao IS NOT NULL))
```
</details>

## `clinico.prontuario`

Prontuário da criança (1:1), aberto automaticamente por trigger.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `prontuario_id` | INT | não | PK | IDENTITY |  |
| `numero` | VARCHAR(12) | não | UQ |  |  |
| `crianca_id` | INT | não | FK → cadastro.crianca (crianca_id), UQ |  |  |
| `unidade_id` | INT | não | FK → cadastro.unidade_saude (unidade_id) |  |  |
| `data_abertura` | DATE | não |  | DEFAULT CAST(SYSDATETIME() AS DATE) |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT df_prontuario_numero DEFAULT ('CC-' + RIGHT('000000' + CAST(NEXT VALUE FOR clinico.seq_prontuario AS VARCHAR(10)), 6))
CONSTRAINT pk_prontuario PRIMARY KEY (prontuario_id)
CONSTRAINT uq_prontuario_numero UNIQUE (numero)
CONSTRAINT uq_prontuario_crianca UNIQUE (crianca_id), -- 1 criança = 1 prontuário (1:1)
CONSTRAINT fk_prontuario_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE
CONSTRAINT fk_prontuario_unidade FOREIGN KEY (unidade_id) REFERENCES cadastro.unidade_saude (unidade_id)
```
</details>

## `clinico.nascimento`

Dados do nascimento de cada bebê (Apgar, IG, medidas, profilaxias).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `nascimento_id` | INT | não | PK | IDENTITY |  |
| `crianca_id` | INT | não | FK → cadastro.crianca (crianca_id), UQ |  |  |
| `hora_nascimento` | TIME(0) | sim |  |  |  |
| `contato_pele_a_pele` | BIT | sim |  |  |  |
| `mamou_primeira_hora` | BIT | sim |  |  |  |
| `apgar_1min` | TINYINT | sim | CK |  |  |
| `apgar_5min` | TINYINT | sim | CK |  |  |
| `clampeamento_oportuno` | BIT | sim |  |  |  |
| `ig_semanas` | TINYINT | sim | CK |  |  |
| `ig_dias` | TINYINT | sim | CK |  |  |
| `ig_metodo` | VARCHAR(10) | sim | CK |  |  |
| `ig_metodo_descricao` | NVARCHAR(100) | sim |  |  |  |
| `peso_g` | SMALLINT | sim | CK |  |  |
| `comprimento_cm` | DECIMAL(4,1) | sim | CK |  |  |
| `perimetro_cefalico_cm` | DECIMAL(4,1) | sim | CK |  |  |
| `reanimacao` | BIT | sim |  |  |  |
| `assistido_por_id` | INT | sim | FK → cadastro.profissional (profissional_id) |  | profissional que assistiu o RN no parto |
| `coombs_direto` | VARCHAR(13) | sim | CK |  |  |
| `profilaxia_oftalmica` | BIT | sim |  |  |  |
| `vitamina_k` | BIT | sim |  |  |  |
| `registrado_por_id` | INT | sim | FK → cadastro.profissional (profissional_id) |  |  |
| `registrado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_nascimento PRIMARY KEY (nascimento_id)
CONSTRAINT uq_nascimento_crianca UNIQUE (crianca_id)
CONSTRAINT fk_nascimento_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE
CONSTRAINT fk_nascimento_assistido FOREIGN KEY (assistido_por_id) REFERENCES cadastro.profissional (profissional_id)
CONSTRAINT fk_nascimento_registrado FOREIGN KEY (registrado_por_id) REFERENCES cadastro.profissional (profissional_id)
CONSTRAINT ck_nascimento_apgar1 CHECK (apgar_1min IS NULL OR apgar_1min BETWEEN 0 AND 10)
CONSTRAINT ck_nascimento_apgar5 CHECK (apgar_5min IS NULL OR apgar_5min BETWEEN 0 AND 10)
CONSTRAINT ck_nascimento_ig_semanas CHECK (ig_semanas IS NULL OR ig_semanas BETWEEN 22 AND 44)
CONSTRAINT ck_nascimento_ig_dias CHECK (ig_dias IS NULL OR ig_dias BETWEEN 0 AND 6)
CONSTRAINT ck_nascimento_ig_metodo CHECK (ig_metodo IS NULL OR ig_metodo IN ('DUM','USG','EXAME_RN','OUTRO'))
CONSTRAINT ck_nascimento_metodo_outro CHECK (ISNULL(ig_metodo,'') <> 'OUTRO' OR ig_metodo_descricao IS NOT NULL)
CONSTRAINT ck_nascimento_peso CHECK (peso_g IS NULL OR peso_g BETWEEN 300 AND 7000)
CONSTRAINT ck_nascimento_comprimento CHECK (comprimento_cm IS NULL OR comprimento_cm BETWEEN 25 AND 65)
CONSTRAINT ck_nascimento_pc CHECK (perimetro_cefalico_cm IS NULL OR perimetro_cefalico_cm BETWEEN 20 AND 45)
CONSTRAINT ck_nascimento_coombs CHECK (coombs_direto IS NULL OR coombs_direto IN ('POSITIVO','NEGATIVO','NAO_REALIZADO'))
```
</details>

## `clinico.internacao_neonatal`

Internação neonatal, quando houve.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `internacao_id` | INT | não | PK | IDENTITY |  |
| `crianca_id` | INT | não | FK → cadastro.crianca (crianca_id), UQ |  |  |
| `motivo` | NVARCHAR(300) | não |  |  |  |
| `data_inicio` | DATE | sim |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_internacao_neonatal PRIMARY KEY (internacao_id)
CONSTRAINT uq_internacao_crianca UNIQUE (crianca_id)
CONSTRAINT fk_internacao_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE
```
</details>

## `clinico.internacao_setor`

Setores e dias de internação (multivalorado).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `internacao_id` | INT | não | FK → clinico.internacao_neonatal (internacao_id), PK |  |  |
| `setor_id` | INT | não | FK → dominio.setor_internacao (setor_id), PK |  |  |
| `dias` | SMALLINT | não | CK |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_internacao_setor PRIMARY KEY (internacao_id, setor_id)
CONSTRAINT fk_intsetor_internacao FOREIGN KEY (internacao_id) REFERENCES clinico.internacao_neonatal (internacao_id) ON DELETE CASCADE
CONSTRAINT fk_intsetor_setor FOREIGN KEY (setor_id) REFERENCES dominio.setor_internacao (setor_id)
CONSTRAINT ck_intsetor_dias CHECK (dias BETWEEN 1 AND 365)
```
</details>

## `clinico.alta_maternidade`

Alta da maternidade: data, medidas, alimentação e resumo.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `alta_id` | INT | não | PK | IDENTITY |  |
| `crianca_id` | INT | não | FK → cadastro.crianca (crianca_id), UQ |  |  |
| `data_alta` | DATE | não |  |  |  |
| `peso_alta_g` | SMALLINT | sim | CK |  |  |
| `comprimento_alta_cm` | DECIMAL(4,1) | sim | CK |  |  |
| `aleitamento` | VARCHAR(5) | sim | CK |  | LME | LM_LA | LA |
| `resumo_alta` | NVARCHAR(1000) | sim |  |  | problemas, diagnósticos, tratamentos, recomendações |
| `registrado_por_id` | INT | sim | FK → cadastro.profissional (profissional_id) |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_alta_maternidade PRIMARY KEY (alta_id)
CONSTRAINT uq_alta_crianca UNIQUE (crianca_id)
CONSTRAINT fk_alta_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE
CONSTRAINT fk_alta_registrado FOREIGN KEY (registrado_por_id) REFERENCES cadastro.profissional (profissional_id)
CONSTRAINT ck_alta_peso CHECK (peso_alta_g IS NULL OR peso_alta_g BETWEEN 300 AND 7000)
CONSTRAINT ck_alta_comprimento CHECK (comprimento_alta_cm IS NULL OR comprimento_alta_cm BETWEEN 25 AND 65)
CONSTRAINT ck_alta_aleitamento CHECK (aleitamento IS NULL OR aleitamento IN ('LME','LM_LA','LA'))
```
</details>

## `clinico.triagem_neonatal`

Um registro por criança e tipo de triagem.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `triagem_id` | INT | não | PK | IDENTITY |  |
| `crianca_id` | INT | não | FK → cadastro.crianca (crianca_id), UQ |  |  |
| `tipo_triagem_id` | INT | não | FK → dominio.tipo_triagem (tipo_triagem_id), UQ |  |  |
| `realizada` | BIT | não | CK |  |  |
| `data_realizacao` | DATE | sim | CK |  |  |
| `metodo` | VARCHAR(5) | sim | CK |  | orelhinha: EOA ou PEATE |
| `data_reteste` | DATE | sim | CK |  | pezinho |
| `conduta` | NVARCHAR(300) | sim |  |  | observação / encaminhamento |
| `profissional_id` | INT | sim | FK → cadastro.profissional (profissional_id) |  |  |
| `registrado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_triagem_neonatal PRIMARY KEY (triagem_id)
CONSTRAINT uq_triagem_crianca_tipo UNIQUE (crianca_id, tipo_triagem_id)
CONSTRAINT fk_triagem_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE
CONSTRAINT fk_triagem_tipo FOREIGN KEY (tipo_triagem_id) REFERENCES dominio.tipo_triagem (tipo_triagem_id)
CONSTRAINT fk_triagem_profissional FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id)
CONSTRAINT ck_triagem_data CHECK ((realizada = 1 AND data_realizacao IS NOT NULL)
CONSTRAINT ck_triagem_metodo CHECK (metodo IS NULL OR metodo IN ('EOA','PEATE'))
CONSTRAINT ck_triagem_reteste CHECK (data_reteste IS NULL OR data_reteste >= data_realizacao)
```
</details>

## `clinico.triagem_resultado_lado`

Resultado por lado (olho/ouvido direito e esquerdo).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `triagem_id` | INT | não | FK → clinico.triagem_neonatal (triagem_id), PK |  |  |
| `lado` | CHAR(1) | não | CK, PK |  | D = direito, E = esquerdo |
| `resultado` | VARCHAR(8) | não | CK |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_triagem_resultado_lado PRIMARY KEY (triagem_id, lado)
CONSTRAINT fk_resultado_lado_triagem FOREIGN KEY (triagem_id) REFERENCES clinico.triagem_neonatal (triagem_id) ON DELETE CASCADE
CONSTRAINT ck_resultado_lado CHECK (lado IN ('D','E'))
CONSTRAINT ck_resultado_lado_valor CHECK (resultado IN ('NORMAL','ALTERADO'))
```
</details>

## `clinico.oximetria_afericao`

Aferições de saturação do teste do coraçãozinho.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `triagem_id` | INT | não | FK → clinico.triagem_neonatal (triagem_id), PK |  |  |
| `numero_afericao` | TINYINT | não | CK, PK |  |  |
| `spo2_mao_direita` | TINYINT | não | CK |  |  |
| `spo2_pe` | TINYINT | não | CK |  |  |
| `aferido_em` | DATETIME | sim |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_oximetria_afericao PRIMARY KEY (triagem_id, numero_afericao)
CONSTRAINT fk_oximetria_triagem FOREIGN KEY (triagem_id) REFERENCES clinico.triagem_neonatal (triagem_id) ON DELETE CASCADE
CONSTRAINT ck_oximetria_numero CHECK (numero_afericao IN (1,2))
CONSTRAINT ck_oximetria_mao CHECK (spo2_mao_direita BETWEEN 50 AND 100)
CONSTRAINT ck_oximetria_pe CHECK (spo2_pe BETWEEN 50 AND 100)
```
</details>

## `seguranca.perfil`

Perfis de acesso do sistema.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `perfil_id` | INT | não | PK | IDENTITY |  |
| `codigo` | VARCHAR(20) | não | CK, UQ |  |  |
| `nome` | NVARCHAR(60) | não |  |  |  |
| `descricao` | NVARCHAR(200) | sim |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_perfil PRIMARY KEY (perfil_id)
CONSTRAINT uq_perfil_codigo UNIQUE (codigo)
CONSTRAINT ck_perfil_codigo CHECK (codigo IN ('RECEPCAO','ENFERMAGEM','MEDICO','GESTOR'))
```
</details>

## `seguranca.usuario`

Usuários do sistema (senha guardada como hash bcrypt).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `usuario_id` | INT | não | PK | IDENTITY |  |
| `login` | VARCHAR(80) | não | UQ |  |  |
| `senha_hash` | CHAR(60) | não | CK |  | bcrypt sempre tem 60 caracteres |
| `perfil_id` | INT | não | FK → seguranca.perfil (perfil_id) |  |  |
| `profissional_id` | INT | sim | FK → cadastro.profissional (profissional_id) |  | recepção/gestão podem não ser profissionais de saúde |
| `nome_exibicao` | NVARCHAR(80) | não |  |  |  |
| `ativo` | BIT | não |  | DEFAULT 1 |  |
| `ultimo_acesso` | DATETIME | sim |  |  |  |
| `criado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_usuario PRIMARY KEY (usuario_id)
CONSTRAINT uq_usuario_login UNIQUE (login)
CONSTRAINT fk_usuario_perfil FOREIGN KEY (perfil_id) REFERENCES seguranca.perfil (perfil_id)
CONSTRAINT fk_usuario_profissional FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id)
CONSTRAINT ck_usuario_hash CHECK (senha_hash LIKE '$2[aby]$%')
```
</details>

## `auditoria.log_auditoria`

Histórico de alterações gravado pelos triggers (antes/depois em JSON).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `log_id` | BIGINT | não | PK | IDENTITY |  |
| `tabela` | SYSNAME | não |  |  |  |
| `operacao` | CHAR(1) | não | CK |  | I = insert, U = update, D = delete |
| `chave` | NVARCHAR(50) | não |  |  | id do registro afetado |
| `usuario_id` | INT | sim |  |  | vem do SESSION_CONTEXT setado pela API |
| `dados_antes` | NVARCHAR | sim | CK |  |  |
| `dados_depois` | NVARCHAR | sim | CK |  |  |
| `data_hora` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_log_auditoria PRIMARY KEY (log_id)
CONSTRAINT ck_log_operacao CHECK (operacao IN ('I','U','D'))
CONSTRAINT ck_log_json_antes CHECK (dados_antes IS NULL OR ISJSON(dados_antes) = 1)
CONSTRAINT ck_log_json_depois CHECK (dados_depois IS NULL OR ISJSON(dados_depois) = 1)
```
</details>

## `atendimento.agendamento`

Agenda: o que foi marcado (exclusão lógica = CANCELADO).

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `agendamento_id` | INT | não | PK | IDENTITY |  |
| `crianca_id` | INT | não | FK → cadastro.crianca (crianca_id) |  |  |
| `profissional_id` | INT | não | FK → cadastro.profissional (profissional_id) |  |  |
| `especialidade_id` | INT | não | FK → dominio.especialidade (especialidade_id) |  |  |
| `unidade_id` | INT | não | FK → cadastro.unidade_saude (unidade_id) |  |  |
| `data_hora` | DATETIME | não |  |  |  |
| `duracao_min` | SMALLINT | não | CK | DEFAULT 30 |  |
| `tipo_atendimento` | VARCHAR(20) | não | CK |  |  |
| `local_atendimento` | VARCHAR(10) | não | CK | DEFAULT 'UNIDADE' |  |
| `status` | VARCHAR(10) | não | CK | DEFAULT 'AGENDADO' |  |
| `motivo_cancelamento` | NVARCHAR(200) | sim | CK |  |  |
| `observacao` | NVARCHAR(200) | sim |  |  |  |
| `criado_por_usuario_id` | INT | sim | FK → seguranca.usuario (usuario_id) |  |  |
| `criado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_agendamento PRIMARY KEY (agendamento_id)
CONSTRAINT fk_agendamento_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id)
CONSTRAINT fk_agendamento_profissional FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id)
CONSTRAINT fk_agendamento_especialidade FOREIGN KEY (especialidade_id) REFERENCES dominio.especialidade (especialidade_id)
CONSTRAINT fk_agendamento_unidade FOREIGN KEY (unidade_id) REFERENCES cadastro.unidade_saude (unidade_id)
CONSTRAINT fk_agendamento_usuario FOREIGN KEY (criado_por_usuario_id) REFERENCES seguranca.usuario (usuario_id)
CONSTRAINT ck_agendamento_duracao CHECK (duracao_min BETWEEN 10 AND 120)
CONSTRAINT ck_agendamento_tipo CHECK (tipo_atendimento IN ('PRIMEIRA_SEMANA','PUERICULTURA','TRIAGEM','VACINA','VISITA_DOMICILIAR'))
CONSTRAINT ck_agendamento_local CHECK (local_atendimento IN ('UNIDADE','DOMICILIO'))
CONSTRAINT ck_agendamento_status CHECK (status IN ('AGENDADO','REALIZADO','CANCELADO','FALTOU'))
CONSTRAINT ck_agendamento_cancelado CHECK (status <> 'CANCELADO' OR motivo_cancelamento IS NOT NULL)
```
</details>

## `atendimento.consulta`

Consulta realizada (edital: entidade Consulta). Inclui a 1ª semana.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `consulta_id` | INT | não | PK | IDENTITY |  |
| `crianca_id` | INT | não | FK → cadastro.crianca (crianca_id) |  |  |
| `profissional_id` | INT | não | FK → cadastro.profissional (profissional_id) |  |  |
| `especialidade_id` | INT | não | FK → dominio.especialidade (especialidade_id) |  |  |
| `unidade_id` | INT | não | FK → cadastro.unidade_saude (unidade_id) |  |  |
| `agendamento_id` | INT | sim | FK → atendimento.agendamento (agendamento_id) |  |  |
| `tipo_atendimento` | VARCHAR(20) | não | CK |  |  |
| `local_atendimento` | VARCHAR(10) | não | CK | DEFAULT 'UNIDADE' |  |
| `data_consulta` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |
| `peso_g` | SMALLINT | sim | CK |  |  |
| `comprimento_cm` | DECIMAL(4,1) | sim | CK |  |  |
| `perimetro_cefalico_cm` | DECIMAL(4,1) | sim | CK |  |  |
| `aleitamento` | VARCHAR(5) | sim | CK |  |  |
| `aleitamento_observacao` | NVARCHAR(200) | sim |  |  |  |
| `dificuldade_amamentar` | BIT | sim | CK |  |  |
| `dificuldade_descricao` | NVARCHAR(200) | sim |  |  |  |
| `parou_amamentar` | BIT | sim |  |  |  |
| `idade_desmame` | NVARCHAR(40) | sim |  |  |  |
| `motivo_desmame` | NVARCHAR(200) | sim |  |  |  |
| `outros_sinais` | NVARCHAR(300) | sim |  |  |  |
| `desenvolvimento_afeto` | NVARCHAR(500) | sim |  |  |  |
| `conduta` | NVARCHAR(500) | sim |  |  |  |
| `registrado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_consulta PRIMARY KEY (consulta_id)
CONSTRAINT fk_consulta_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id)
CONSTRAINT fk_consulta_profissional FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id)
CONSTRAINT fk_consulta_especialidade FOREIGN KEY (especialidade_id) REFERENCES dominio.especialidade (especialidade_id)
CONSTRAINT fk_consulta_unidade FOREIGN KEY (unidade_id) REFERENCES cadastro.unidade_saude (unidade_id)
CONSTRAINT fk_consulta_agendamento FOREIGN KEY (agendamento_id) REFERENCES atendimento.agendamento (agendamento_id)
CONSTRAINT ck_consulta_tipo CHECK (tipo_atendimento IN ('PRIMEIRA_SEMANA','PUERICULTURA','TRIAGEM','VACINA','VISITA_DOMICILIAR'))
CONSTRAINT ck_consulta_local CHECK (local_atendimento IN ('UNIDADE','DOMICILIO'))
CONSTRAINT ck_consulta_peso CHECK (peso_g IS NULL OR peso_g BETWEEN 300 AND 30000)
CONSTRAINT ck_consulta_comprimento CHECK (comprimento_cm IS NULL OR comprimento_cm BETWEEN 25 AND 130)
CONSTRAINT ck_consulta_pc CHECK (perimetro_cefalico_cm IS NULL OR perimetro_cefalico_cm BETWEEN 20 AND 60)
CONSTRAINT ck_consulta_aleitamento CHECK (aleitamento IS NULL OR aleitamento IN ('LME','LM_LA','LA'))
CONSTRAINT ck_consulta_dificuldade CHECK (ISNULL(dificuldade_amamentar,0) = 0 OR dificuldade_descricao IS NOT NULL)
CONSTRAINT ck_consulta_medidas_1sem CHECK (tipo_atendimento <> 'PRIMEIRA_SEMANA'
```
</details>

## `atendimento.consulta_sinal_alerta`

Resposta Sim/Não de cada sinal de alerta na consulta.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `consulta_id` | INT | não | FK → atendimento.consulta (consulta_id), PK |  |  |
| `sinal_alerta_id` | INT | não | FK → dominio.sinal_alerta (sinal_alerta_id), PK |  |  |
| `presente` | BIT | não |  |  |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_consulta_sinal_alerta PRIMARY KEY (consulta_id, sinal_alerta_id)
CONSTRAINT fk_consinal_consulta FOREIGN KEY (consulta_id) REFERENCES atendimento.consulta (consulta_id) ON DELETE CASCADE
CONSTRAINT fk_consinal_sinal FOREIGN KEY (sinal_alerta_id) REFERENCES dominio.sinal_alerta (sinal_alerta_id)
```
</details>

## `atendimento.vacina_aplicada`

Vacinas aplicadas na criança.

| Coluna | Tipo | Nulo? | Chaves / regras | Padrão | Observação |
|---|---|---|---|---|---|
| `vacina_aplicada_id` | INT | não | PK | IDENTITY |  |
| `crianca_id` | INT | não | FK → cadastro.crianca (crianca_id), UQ |  |  |
| `vacina_id` | INT | não | FK → dominio.vacina (vacina_id), UQ |  |  |
| `dose` | VARCHAR(4) | não | CK, UQ |  |  |
| `data_aplicacao` | DATE | não |  |  |  |
| `lote` | VARCHAR(20) | sim |  |  |  |
| `profissional_id` | INT | sim | FK → cadastro.profissional (profissional_id) |  |  |
| `unidade_id` | INT | não | FK → cadastro.unidade_saude (unidade_id) |  |  |
| `consulta_id` | INT | sim | FK → atendimento.consulta (consulta_id) |  |  |
| `registrado_em` | DATETIME | não |  | DEFAULT SYSDATETIME() |  |

<details><summary>Restrições (constraints)</summary>

```sql
CONSTRAINT pk_vacina_aplicada PRIMARY KEY (vacina_aplicada_id)
CONSTRAINT uq_vacina_aplicada_dose UNIQUE (crianca_id, vacina_id, dose)
CONSTRAINT fk_vacapl_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE
CONSTRAINT fk_vacapl_vacina FOREIGN KEY (vacina_id) REFERENCES dominio.vacina (vacina_id)
CONSTRAINT fk_vacapl_profissional FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id)
CONSTRAINT fk_vacapl_unidade FOREIGN KEY (unidade_id) REFERENCES cadastro.unidade_saude (unidade_id)
CONSTRAINT fk_vacapl_consulta FOREIGN KEY (consulta_id) REFERENCES atendimento.consulta (consulta_id)
CONSTRAINT ck_vacapl_dose CHECK (dose IN ('DU','D1','D2','D3','REF'))
```
</details>
