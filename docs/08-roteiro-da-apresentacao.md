# 8. Roteiro da apresentação (15–20 min)

Segue a "Ordem da Demonstração" do edital (seção 5). Antes de começar: `npm run db:reset` e `npm start`.

## 1. Regra de negócio e DER (4 min)
- Contexto: Caderneta da Criança em papel → digital, foco em ergonomia e internet instável ([05](05-requisitos-e-regras-de-negocio.md)).
- Mostrar o DER ([02](02-der.md)): gestação como eixo; gêmeos; grades viraram linhas.
- Normalização em 30 s ([03](03-normalizacao-3fn.md), parágrafo final).

## 2. Ambiente: VM + DBeaver (4 min)
- Mostrar a VM ligada no VirtualBox e `systemctl status mssql-server`.
- DBeaver: schemas `dominio/cadastro/clinico/atendimento/...`, abrir `clinico.nascimento` → aba *Constraints* (CHECKs) e *Foreign Keys*.
- Rodar ao vivo 2 ou 3 consultas de `04_dql` (sugestão: **Q1** agenda de hoje, **Q15** PIVOT das sorologias, **Q7** por especialidade).

## 3. Aplicação CRUD (6 min), sempre conferindo no DBeaver
1. **Create:** login `recepcao@` → *Crianças* → cadastrar bebê com mãe nova → abre a caderneta. No DBeaver: `SELECT * FROM clinico.prontuario ORDER BY 1 DESC` mostra o prontuário criado **pelo trigger**.
2. **Create (procedure):** *Agenda* → agendar a 1ª semana. Tentar o **mesmo horário** de novo → erro vindo do `THROW` da procedure.
3. **Read:** *Profissionais* filtrando "Pediatria"; *Caderneta* da Laura (alertas de cuidado especial, olhinho alterado).
4. **Update:** login `enfermeira@` → registrar a consulta da 1ª semana (botão "Nenhum sinal de alerta", % de perda de peso). O agendamento vira REALIZADO **pelo trigger**.
5. **Delete:** cancelar um agendamento (lógico) e, como `gestor@`, excluir o cancelado (físico). Em *Relatórios → Auditoria*, mostrar o log com antes/depois.
6. (Extra) Desligar o Wi-Fi, salvar uma triagem → "salvo neste aparelho"; religar → envia sozinho.

## 4. Perguntas individuais: cola de respostas
| Pergunta provável | Resposta curta |
|---|---|
| Por que SQL Server? | SGBD relacional com T-SQL completo (procedures, triggers, MERGE, OPENJSON, índices filtrados), roda em Linux na VM e conecta no DBeaver. |
| Diferença entre `WHERE` e `HAVING`? | WHERE filtra linhas **antes** do GROUP BY; HAVING filtra **grupos** depois (Q11). |
| `INNER` × `LEFT JOIN`? | INNER traz só o que tem par; LEFT traz tudo da esquerda e NULL onde não tem par. Q6 usa LEFT + IS NULL para achar quem **não** teve consulta. |
| O que é índice filtrado? | índice só com as linhas do WHERE. Usado para "CPF único quando informado" e "um horário por profissional só entre os AGENDADOS". |
| Por que procedure e não só INSERT? | a regra precisa olhar outras linhas (conflito de horário) dentro de uma transação com trava (`UPDLOCK, HOLDLOCK`). |
| Como a auditoria sabe o usuário? | a API faz `sp_set_session_context 'usuario_id'` na mesma transação; o trigger lê `SESSION_CONTEXT`. |
| Como evitam SQL Injection? | todo SQL usa parâmetros `@nome` (`request.input`), nunca concatenação. |
| Exclusão lógica × física? | lógica muda status/ativo e preserva histórico (padrão na saúde); física é `DELETE`, só para duplicados e bloqueada pela FK se houver histórico. |
| Por que AIG/PIG/GIG não é coluna? | é derivada de peso + IG + sexo; guardar criaria dependência transitiva (fere a 3FN) e risco de inconsistência. |
