/* =====================================================================
   executar_tudo.sql  —  roda TODOS os scripts na ordem certa
   ---------------------------------------------------------------------
   Opção 1 (recomendada): na pasta backend, "npm run db:setup"
   Opção 2: SSMS com "Query > SQLCMD Mode" ligado, abrindo este arquivo
            a partir da pasta database
   Opção 3: terminal, dentro da pasta database:
      sqlcmd -S localhost,1433 -U sa -P "SUA_SENHA" -I -i executar_tudo.sql
      (-I liga QUOTED_IDENTIFIER, necessário para índices filtrados)

   :r é um comando do SQLCMD que "cola" o conteúdo de outro arquivo aqui.
   Descomente a linha do 00_reset se quiser apagar tudo antes.
   ===================================================================== */
:on error exit

-- :r 00_reset/00_drop_database.sql

:r 01_ddl/01_create_database.sql
:r 01_ddl/02_create_schemas.sql
:r 01_ddl/03_drop_tables.sql
:r 01_ddl/04_tabelas_dominio.sql
:r 01_ddl/05_tabelas_cadastro.sql
:r 01_ddl/06_tabelas_gestacao_parto.sql
:r 01_ddl/07_tabelas_crianca_neonatal.sql
:r 01_ddl/08_tabelas_seguranca.sql
:r 01_ddl/09_tabelas_atendimento.sql
:r 01_ddl/10_indices.sql
:r 01_ddl/11_alter_table_exemplos.sql

:r 02_programabilidade/01_funcoes.sql
:r 02_programabilidade/02_views.sql
:r 02_programabilidade/03_procedures.sql
:r 02_programabilidade/04_triggers.sql

:r 03_dml/01_carga_dominios.sql
:r 03_dml/02_carga_cadastro.sql
:r 03_dml/03_carga_gestacao_nascimento.sql
:r 03_dml/04_carga_triagens.sql
:r 03_dml/05_carga_usuarios.sql
:r 03_dml/06_carga_agenda_consultas_vacinas.sql
:r 03_dml/07_update_exemplos.sql
:r 03_dml/08_delete_exemplos.sql

:r 05_dcl/01_logins_usuarios_permissoes.sql

PRINT 'Banco CadernetaDigital pronto.';
GO
