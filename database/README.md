# Scripts SQL (Microsoft SQL Server / T-SQL)

Cada assunto num arquivo separado. **Execute na ordem dos números.**

| Pasta | Tipo | Conteúdo |
|---|---|---|
| `00_reset/` | DDL | `DROP DATABASE` (só quando quiser recomeçar) |
| `01_ddl/` | **DDL** | banco, schemas, `DROP TABLE IF EXISTS`, tabelas por domínio, índices, `ALTER TABLE` |
| `02_programabilidade/` | DDL | funções, views, procedures, triggers |
| `03_dml/` | **DML** | massa de teste (`INSERT`), exemplos de `UPDATE` e `DELETE` |
| `04_dql/` | **DQL** | 20 consultas comentadas: JOINs, agregações, filtros temporais, CTE, PIVOT, JSON |
| `05_dcl/` | DCL | logins, usuários, roles, `GRANT`/`DENY` |

Como rodar: `cd backend && npm run db:setup` (ou veja `../docs/06-guia-vm-sqlserver-dbeaver.md`).

A massa de teste usa datas **relativas a hoje**: os recém-nascidos sempre têm poucos dias de vida, em qualquer dia em que o script rodar.

Para regerar o dicionário de dados depois de mudar uma tabela: `python database/ferramentas/gerar_dicionario.py`.
