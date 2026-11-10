# 5. Contexto, requisitos e regras de negócio

## Contexto de aplicabilidade (escolha do grupo)

**Cenário do edital:** Clínica SaúdeDigital · **Contexto específico escolhido:** *redesenho de atendimento*, ou seja, a **Caderneta Digital da Criança** de uma rede municipal de saúde (documento "A3 · Redesenho").

Hoje enfermeiros(as), técnicos(as) e médicos(as) preenchem **em papel** os registros de pré-natal, parto, nascimento, internação neonatal, alta, triagens neonatais e consulta da 1ª semana. O sistema eletrônico antigo recebeu reclamações: muitos campos, pressão de tempo e **internet instável** (enfermarias, visitas domiciliares, UBS). O objetivo é **reduzir a carga de trabalho sem perder nenhuma informação clínica** dos formulários.

**Por que esse contexto justifica o modelo:**
- muitas perguntas Sim/Não e grades → normalização forte (tabelas de domínio e tabelas de resposta);
- vários profissionais tocam o mesmo prontuário → auditoria de quem fez o quê;
- prazos clínicos curtos (triagens até o 7º dia, consulta do 3º ao 5º dia) → views que calculam pendências;
- gêmeos, parto domiciliar e mãe sem pré-natal → o modelo precisa aceitar esses casos sem gambiarra.

## Atores (perfis do sistema)

| Perfil | O que faz |
|---|---|
| Recepção | cadastra mãe e criança, gerencia a agenda, consulta a caderneta |
| Enfermagem (enfermeiro/técnico) | preenche pré-natal, nascimento, alta e triagens; registra consulta e vacinas |
| Médico(a) | registra consultas e dados clínicos; consulta a agenda |
| Gestão | relatórios, auditoria, exclusões físicas e gerência da agenda |

## Requisitos funcionais (mapa para o edital)

| Código | Requisito | Edital | Onde |
|---|---|---|---|
| RF01 | Login com senha criptografada (bcrypt) e perfis | — | `seguranca.*`, `authService.js` |
| RF02 | Cadastrar criança + mãe numa tela (mãe existente, nova ou gêmeo) | **Create** | `criancas.html`, `POST /criancas` |
| RF03 | Buscar criança por nome dela, da mãe, CNS ou prontuário | **Read** | `GET /criancas`, Q2 |
| RF04 | Filtrar e exibir **médicos/profissionais** por especialidade, categoria e unidade | **Read** | `profissionais.html`, Q3 |
| RF05 | **Agendar consulta** com checagem de conflito de horário | **Create** | `sp_agendar_consulta` |
| RF06 | Exibir **consultas e prontuário** (linha do tempo) | **Read** | `caderneta.html`, `vw_linha_tempo_crianca` |
| RF07 | Cancelar agendamento (**exclusão lógica**) e excluir cancelados (**física**) | **Delete** | `sp_cancelar_agendamento`, `DELETE /agendamentos/:id` |
| RF08 | Inativar criança (lógica) e excluir duplicado (física, só gestão) | **Delete** | `sp_inativar_crianca` |
| RF09 | Registrar pré-natal, parto/nascimento, internação/alta, triagens | Update | `PUT /criancas/:id/...` (MERGE) |
| RF10 | Registrar consulta da 1ª semana com sinais de alerta | Create | `sp_registrar_consulta` |
| RF11 | Registrar vacinas aplicadas | Create | `vacina_aplicada` |
| RF12 | Painel com pendências do dia | Read | `inicio.html`, `dashboardRepository` |
| RF13 | Relatórios gerenciais mostrando o SQL | DQL | `relatorios.html` |
| RF14 | Auditoria de alterações | — | triggers `trg_auditoria_*` |

## Requisitos não funcionais

| Código | Requisito | Como foi atendido |
|---|---|---|
| RNF01 | SGBD relacional SQL Server em VM | ver [guia da VM](06-guia-vm-sqlserver-dbeaver.md) |
| RNF02 | Segurança | menor privilégio (`app_caderneta`), JWT, bcrypt, SQL parametrizado, limite de tentativas de login |
| RNF03 | Funcionar com internet instável | rascunho automático no aparelho + fila de envio quando a rede volta |
| RNF04 | Ergonomia | Sim/Não com 1 toque, campos condicionais, botão "Nenhum sinal de alerta", alvos de 44 px, alertas ao vivo |
| RNF05 | Rastreabilidade | log de auditoria com antes/depois em JSON e usuário via `SESSION_CONTEXT` |

## Regras de negócio (e onde cada uma é garantida)

| # | Regra | Garantida por |
|---|---|---|
| RN01 | Mãe precisa de CPF **ou** CNS | `ck_gestante_documento` |
| RN02 | Quem não fez pré-natal não tem nº de consultas nem trimestre | `ck_gestacao_prenatal` |
| RN03 | Gravidez de risco exige dizer qual | `ck_gestacao_risco` |
| RN04 | Cesárea exige motivo; local "Outro" exige descrição | `ck_parto_cesarea`, `ck_parto_local_outro` |
| RN05 | Apgar entre 0 e 10; IG 22–44 semanas e 0–6 dias; peso 300–7.000 g | CHECKs de `nascimento` |
| RN06 | Gêmeos compartilham gestação e parto | modelo (criança → gestação; parto 1:1 gestação) |
| RN07 | Toda criança tem um prontuário, número sequencial CC-000001 | `SEQUENCE` + `trg_crianca_abrir_prontuario` |
| RN08 | Adequação peso/IG: < p10 PIG, > p90 GIG, senão AIG | `fn_classificar_peso_ig` + `referencia_peso_ig` |
| RN09 | "Cuidado especial" se peso < 2.500 g, IG < 37 sem, Apgar 5' < 7, mãe < 20 anos ou passou pela UTIN | `vw_crianca_resumo` |
| RN10 | Coraçãozinho normal: SpO₂ ≥ 95% nas duas medidas e diferença < 3%; se alterar, repetir em 1 h; se alterar de novo, ALTERADO | `fn_resultado_oximetria` |
| RN11 | Triagem realizada ⇔ tem data; data não pode ser antes do nascimento | `ck_triagem_data`, `trg_triagem_valida_data` |
| RN12 | Uma triagem de cada tipo por criança | `uq_triagem_crianca_tipo` |
| RN13 | Triagem sem registro e fora do prazo = ATRASADA | `vw_triagem_situacao` |
| RN14 | Consulta da 1ª semana exige peso, comprimento e PC | `ck_consulta_medidas_1sem` |
| RN15 | Consulta da 1ª semana só até o 7º dia e uma única vez | `sp_agendar_consulta` (THROW 50014/50015) |
| RN16 | Profissional não pode ter dois atendimentos sobrepostos | `sp_agendar_consulta` (UPDLOCK/HOLDLOCK) + índice único filtrado |
| RN17 | Só agenda com profissional habilitado na especialidade | `sp_agendar_consulta` (THROW 50012) |
| RN18 | Cancelar exige motivo; consulta registrada marca o agendamento como REALIZADO | `ck_agendamento_cancelado`, `trg_consulta_conclui_agendamento` |
| RN19 | Inativar criança cancela os agendamentos futuros | `sp_inativar_crianca` |
| RN20 | Não se apaga criança/especialidade com histórico | FKs sem `ON DELETE CASCADE` |
| RN21 | Mesma dose da mesma vacina não pode ser lançada 2 vezes | `uq_vacina_aplicada_dose` |
| RN22 | Senha nunca em texto; log de auditoria só por trigger | `ck_usuario_hash`, `DENY UPDATE, DELETE ON SCHEMA::auditoria` |
