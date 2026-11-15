# Redesenho enxuto do DER — Caderneta Digital da Criança (UBS/USF)

> Versão 2 (substitui a proposta ampla de 44 tabelas). Objetivo: cobrir o formulário `A3_Redesenho_Saude.pdf`, adicionar **calendário vacinal** e **agendamento melhorado**, sem complicar o modelo.
> Contexto: atenção primária (ambulatorial). **Não há reinternação.** Parto, nascimento, internação neonatal e alta são **transcritos da maternidade**; consulta, puericultura, pezinho, vacinas e agenda são **gerados na UBS**.

## 1. Diagnóstico em uma frase

O modelo atual (33 tabelas) já cobre quase todos os campos do PDF. O que falta é pouco: fatores de vulnerabilidade, calendário vacinal, agenda com grade de horários, escopo por unidade e auditoria mais ampla. Por isso a proposta é **ajustar, não refazer**: 33 → **39 tabelas** (40 com `bloqueio_agenda`, opcional).

## 2. O que muda (resumo)

| Área | Mudança | Tabelas novas |
|---|---|---|
| Cuidado especial (PDF) | Fatores: vulnerabilidade social, área de risco, deficiência, asfixia grave, mãe usuária de drogas/depressão | `fator_vulnerabilidade`, `crianca_vulnerabilidade` |
| **Calendário vacinal** | Regra por vacina/dose (idade mínima, ideal, máxima, intervalo). Situação **calculada**, não gravada | `calendario_vacinal` + view `vw_situacao_vacinal` |
| **Agenda** | Grade de atendimento do profissional, horários livres calculados, chegada, novos status, reagendamento, busca ativa | `grade_atendimento` (+ `bloqueio_agenda` opcional) |
| Segurança | 5 perfis, permissões no banco, escopo por unidade na API | `perfil`, `permissao`, `perfil_permissao` (se ainda não existirem) |
| Auditoria | Triggers em mais tabelas (hoje só 4) | — |
| Integridade | Trocar `ON DELETE CASCADE` (14 FKs) por exclusão lógica | — |

Não entra (de propósito): reinternação, retestes múltiplos, ACS/microárea, blockchain, Mongo, encaminhamento/rede de apoio como módulos próprios.

## 3. Calendário vacinal

**Tabela `calendario_vacinal`**: `vacina_id`, `dose`, `idade_minima_dias`, `idade_ideal_dias`, `idade_maxima_dias`, `intervalo_dose_anterior_dias`. Única por (vacina, dose).

**Situação calculada** pela view `vw_situacao_vacinal` (por criança × dose do calendário), nunca gravada:

| Situação | Regra |
|---|---|
| Aplicada | existe `vacina_aplicada` para a vacina/dose |
| Disponível | idade ≥ mínima e intervalo da dose anterior cumprido |
| Atrasada | idade > ideal (ou > máxima) e não aplicada |
| Prevista | idade < mínima |

`vacina_aplicada.origem` distingue **transcrita da caderneta/maternidade** (ex.: BCG, Hep. B ao nascer) de **aplicada na UBS**. `consulta_id` opcional liga a dose à consulta.

Uso: tela "espelho da caderneta" (inspirada no e-SUS APS) e lista de **vacinas atrasadas** que alimenta a busca ativa da agenda.

## 4. Agendamento melhorado (inspirado em e-SUS APS/PEC e no PEC_APS_Prototipe)

1. **`grade_atendimento`**: dia da semana, hora início/fim, duração do slot, por profissional e unidade. Horários livres = grade − agendamentos − bloqueios, **calculados**.
2. **Só horários futuros e livres** na tela; conflito barrado pela `sp_agendar_consulta` (UPDLOCK/HOLDLOCK, mantida).
3. **Status**: `AGENDADO → CONFIRMADO → PRESENTE (chegada_em) → REALIZADO`; saídas: `CANCELADO` (com `motivo_cancelamento`), `FALTOU`, `NAO_AGUARDOU`.
4. **Reagendamento** com vínculo (`reagendado_de_id`), preservando histórico.
5. **Tipo de atendimento** (consulta, puericultura, vacinação, retorno, visita) e `local_atendimento` (UBS/domicílio).
6. **Busca ativa**: view com crianças com vacina atrasada, faltosas sem reagendamento e sem consulta de puericultura no prazo.
7. **Impressão** da agenda do dia e do comprovante; **absenteísmo** por período/profissional no relatório do gestor.
8. **Escopo**: toda consulta/agenda filtra pela unidade do usuário (API), corrigindo `?unidade_id=` aceito livremente hoje.

## 5. DER (arquivos)

- `der-principal.mmd/.svg` — visão geral (~16 entidades)
- `der-caderneta.mmd/.svg` — pré-natal, parto, nascimento, internação, alta, vulnerabilidades
- `der-atendimento-vacinacao.mmd/.svg` — agenda, consulta, triagens, calendário e vacinas
- `der-seguranca.mmd/.svg` — usuários, perfis, permissões, auditoria

Todos validados com Mermaid.

## 6. Perfis e permissões (5 perfis, 1 unidade por usuário)

| Capacidade | Recepção | Enfermagem | Médico | Gestor | Admin |
|---|:-:|:-:|:-:|:-:|:-:|
| Cadastrar criança/gestante | ✔ | ✔ | — | — | ✔ |
| Agendar / reagendar / cancelar | ✔ | ✔ | ✔ | — | ✔ |
| Marcar chegada | ✔ | ✔ | — | — | ✔ |
| Registrar triagem e vacina | — | ✔ | ✔ | — | ✔ |
| Registrar consulta | — | ✔* | ✔ | — | ✔ |
| Ver caderneta clínica | — | ✔ | ✔ | — | ✔ |
| Relatórios agregados (absenteísmo, cobertura) | — | — | — | ✔ | ✔ |
| Excluir | — | — | — | — | ✔ (lógica) |

\* A confirmar quem pode registrar consulta de puericultura na unidade.
Gestor vê **agregados**, sem detalhe clínico individual. Permissões ficam no banco; escopo de unidade é aplicado na API (opcional: Row-Level Security).

## 7. Migração (sem destruir o atual)

1. Criar tabelas novas e colunas (`ALTER`/`CREATE`, sem `DROP`).
2. Carregar `calendario_vacinal` e fatores de vulnerabilidade (seeds).
3. Criar `grade_atendimento` a partir do horário de trabalho dos profissionais.
4. Mapear status antigos (`AGENDADO/REALIZADO/CANCELADO/FALTOU`) → novos (compatíveis).
5. Trocar cascades por exclusão lógica e ampliar triggers de auditoria.
6. Ajustar `sp_agendar_consulta`, `permissoes.js` e rotas de agenda/dashboard.

## 8. Roteiro de validação (estilo PEC_APS, 8–10 casos)

1. Recepção cria agendamento em horário livre → 201.
2. Mesmo horário/profissional → erro de conflito (50010–50015).
3. Horário fora da grade ou no passado → 400.
4. Marcar chegada e depois consulta → status `REALIZADO`.
5. Cancelar com motivo e reagendar → novo registro vinculado.
6. Usuário da unidade A tenta ver criança da unidade B → 403.
7. Recepção tenta abrir caderneta clínica → 403.
8. Gestor vê absenteísmo agregado, mas não consulta individual → 200/403.
9. Criança de 3 meses sem 2ª dose do calendário → aparece "atrasada" e na busca ativa.
10. Excluir criança → exclusão lógica, auditoria registrada.

## 9. Revisão crítica — o que precisa de validação

- **Valores do calendário** (idades/intervalos): usar o calendário oficial do Ministério da Saúde vigente e validar com o professor/profissional de saúde. Não os considere finais.
- Códigos de dose das vacinas e quem pode registrar triagem/vacina.
- **LGPD**: lista nominal de pendentes/faltosos só para perfis da unidade.
- Tabela de referência AIG/PIG/GIG (cálculo derivado).
- Comparações com Tasy/MV/Smart não foram verificadas; o embasamento foi e-SUS APS (manual) e PEC_APS_Prototipe.
- O **frontend não foi analisado** em detalhe (só `agenda.html`).
