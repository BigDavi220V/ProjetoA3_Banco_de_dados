# 3. Memorial de normalização (até a 3ª Forma Normal)

Ponto de partida: os formulários em papel da Caderneta da Criança (Anexos I.a e I.b). Imagine que alguém digitou **uma folha inteira em uma única tabela gigante**:

```
FICHA_PAPEL (
  nome_bebe, sexo, data_nasc, cns_bebe, tipo_sang_bebe,
  nome_mae, cpf_mae, nasc_mae, endereco_mae, telefones_mae, tipo_sang_mae,
  gravidez_planejada, fez_prenatal, n_consultas, trimestre_inicio, tipo_gravidez, risco, qual_risco,
  sifilis_t1, sifilis_t2, sifilis_t3, hepatite_t1, hepatite_t2, hepatite_t3,
  toxo_t1, toxo_t2, toxo_t3, zika_t1, zika_t2, zika_t3,
  dtpa, influenza, hepb_gestante, covid,
  local_parto, nome_maternidade, cnes_maternidade, endereco_maternidade, tipo_parto, motivo_cesarea, acompanhante,
  hora_nasc, apgar1, apgar5, ig_sem, ig_dias, metodo_ig, peso, comprimento, pc, adequacao_peso_ig,
  reanimacao, assistido_por, crm_assistente, coombs_ci, coombs_cd, oftalmica, vit_k,
  internado, utin_dias, ucinco_dias, ucinca_dias, alcon_dias, motivo_internacao,
  data_alta, peso_alta, comp_alta, alimentacao_alta, resumo_alta,
  olhinho_data, olho_d, olho_e, coracao_data, spo2_mao, spo2_pe, orelhinha_data, ouvido_d, ouvido_e, pezinho_data, reteste,
  consulta_data, consulta_peso, ..., coto, ictericia, diarreia, febre, ..., profissional_consulta, crm_profissional
)
```

São mais de 100 colunas, com muitos problemas: repetição, campos que valem para um bebê e não para o outro (gêmeos) e dados que se contradizem.

---

## 1ª Forma Normal: valores atômicos e sem grupos repetidos

**Regra:** cada célula guarda **um valor só**, e não existem "colunas numeradas" que repetem a mesma informação.

| Problema na ficha | Tipo | Solução | Tabela criada |
|---|---|---|---|
| `endereco_mae` = "Rua X, 15, Pirajá, 40335-000" | atributo **composto** | quebrar em partes atômicas | colunas `logradouro`, `numero`, `bairro`, `cep`... em `cadastro.gestante` |
| `telefones_mae` = "9881..., 3322..." | atributo **multivalorado** | uma linha por telefone | `cadastro.gestante_telefone` |
| `sifilis_t1 … zika_t3` (12 colunas) | **grupo repetido** | uma linha por (agravo, trimestre) | `clinico.sorologia_prenatal` |
| `dtpa, influenza, hepb, covid` | grupo repetido | uma linha por vacina | `clinico.vacina_prenatal` |
| `utin_dias, ucinco_dias, ...` | grupo repetido | uma linha por setor | `clinico.internacao_setor` |
| `olho_d, olho_e, ouvido_d, ouvido_e` | grupo repetido | uma linha por lado | `clinico.triagem_resultado_lado` |
| `coto, ictericia, febre, ...` (8 perguntas) | grupo repetido | uma linha por sinal | `atendimento.consulta_sinal_alerta` |
| 1ª e 2ª aferição do coraçãozinho | grupo repetido | uma linha por aferição | `clinico.oximetria_afericao` |
| várias consultas na mesma ficha | grupo repetido | uma linha por consulta | `atendimento.consulta` |

> Ganho imediato: para incluir um novo agravo (ex.: HIV) basta **inserir uma linha** em `dominio.agravo`. Nenhuma tabela precisa de coluna nova.

## 2ª Forma Normal: sem dependência PARCIAL da chave

**Regra:** em tabelas de **chave composta**, cada coluna precisa depender da chave **inteira**, e não só de uma parte dela.

Exemplo: depois da 1FN, a sorologia ficou com chave `(gestacao_id, agravo_id, trimestre)`. Se deixássemos lá o `nome_agravo`:

```
sorologia (gestacao_id, agravo_id, trimestre, resultado, nome_agravo)
                         └──────────────────────────────────┘
               nome_agravo depende SÓ de agravo_id  → dependência parcial ✗
```

**Solução:** `nome_agravo` e `cid10` foram para `dominio.agravo`. A sorologia guarda só `resultado`, que depende da chave inteira (qual gestação, qual agravo, qual trimestre).

Outros casos tratados:

| Tabela com chave composta | Coluna que dependia só de parte | Para onde foi |
|---|---|---|
| `profissional_especialidade (profissional_id, especialidade_id)` | nome do profissional / nome da especialidade | `cadastro.profissional` / `dominio.especialidade` |
| `internacao_setor (internacao_id, setor_id)` | nome do setor ("Unidade de Terapia Intensiva…") | `dominio.setor_internacao` |
| `consulta_sinal_alerta (consulta_id, sinal_alerta_id)` | texto do sinal e critério ("FR > 60 ou < 30") | `dominio.sinal_alerta` |
| `vacina_prenatal (gestacao_id, vacina_id)` | nome da vacina | `dominio.vacina` |
| `referencia_peso_ig (ig_semanas, sexo)` | (só tem p10 e p90, que dependem dos dois) | já estava em 2FN |

## 3ª Forma Normal: sem dependência TRANSITIVA

**Regra:** nenhuma coluna pode depender de **outra coluna que não é chave** (A → B → C).

| Dependência transitiva encontrada | Por que é problema | Solução |
|---|---|---|
| `crianca_id → maternidade_id → nome/CNES/endereço da maternidade` | trocar o endereço exigiria atualizar todos os partos | `cadastro.unidade_saude`; o parto guarda só `unidade_id` |
| `crianca_id → crm_assistente → nome do assistente` | médico com o nome digitado de 3 formas diferentes | `cadastro.profissional`; `nascimento.assistido_por_id` |
| `crianca_id → mae_id → dados da mãe` | gêmeos repetiriam a mãe inteira | criança → **gestação** → gestante |
| `crianca_id → gestacao → dados do parto` | gêmeos repetiriam o parto | `clinico.parto` com `UNIQUE (gestacao_id)` (1:1 com a gestação) |
| `tipo_sang_mae`, `coombs_ci` na ficha do bebê | são dados da **mãe/gestação**, não do bebê | `gestante.tipo_sanguineo`, `gestacao.coombs_indireto`; o bebê fica com `crianca.tipo_sanguineo` e `nascimento.coombs_direto` |
| `peso, ig_semanas, sexo → adequacao_peso_ig` | campo **derivado**: se alguém corrige o peso, a adequação fica errada | **não é armazenada**; é calculada por `clinico.fn_classificar_peso_ig` |
| `categoria → conselho (CRM/COREN)` | o conselho depende da categoria, não do profissional | `dominio.categoria_profissional.conselho` |

### Verificação final (cada tabela em 3FN)

Para cada tabela fizemos a pergunta: *"esta coluna fala da **chave**, da **chave inteira** e de **nada além da chave**?"* Exemplos:

- `clinico.nascimento`: Apgar, IG, peso, PC dependem do **nascimento daquele bebê** ✔
- `clinico.parto`: tipo e local dependem do **parto daquela gestação** ✔
- `atendimento.consulta`: medidas e aleitamento dependem **daquela consulta** ✔

### Desnormalizações conscientes (e por quê)

| O que | Por que mantivemos |
|---|---|
| `crianca.data_nascimento` e `parto.data_parto` | parecem iguais, mas o parto pode começar num dia e o 2º gêmeo nascer depois da meia-noite. Além disso, a criança pode ser cadastrada antes do parto ser registrado. |
| `consulta.unidade_id` mesmo com `agendamento.unidade_id` | consultas sem agendamento (demanda espontânea, visita) também precisam da unidade. |

---

### Resumo para a banca (30 segundos)

> "Partimos da ficha em papel como uma tabela única. Na **1FN** separamos endereço (composto), telefones (multivalorado) e as grades de sorologia, vacinas, setores, lados e sinais de alerta, que viraram linhas. Na **2FN** tiramos das tabelas de chave composta os nomes que dependiam só de parte da chave e criamos o schema `dominio`. Na **3FN** eliminamos as dependências transitivas: maternidade, profissional, mãe e parto viraram entidades próprias, e a adequação peso/IG deixou de ser armazenada e passou a ser calculada por função."
