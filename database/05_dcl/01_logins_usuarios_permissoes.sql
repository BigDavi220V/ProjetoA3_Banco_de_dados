/* =====================================================================
   01_logins_usuarios_permissoes.sql  —  DCL: quem pode fazer o quê
   ---------------------------------------------------------------------
   Princípio do MENOR PRIVILÉGIO: a aplicação NÃO conecta como "sa".
     LOGIN  = acesso ao SERVIDOR SQL Server (fica no master)
     USER   = acesso a ESTE banco (ligado ao login)
     ROLE   = grupo de permissões; damos GRANT na role, não na pessoa
   Permissões dadas por SCHEMA (por isso a arquitetura em schemas ajuda).

   >>> TROQUE A SENHA ANTES DE USAR FORA DA SALA DE AULA <<<
   ===================================================================== */
USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'app_caderneta')
    CREATE LOGIN app_caderneta WITH PASSWORD = N'Caderneta@A3_2026', CHECK_POLICY = ON, DEFAULT_DATABASE = CadernetaDigital;

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'gestao_leitura')
    CREATE LOGIN gestao_leitura WITH PASSWORD = N'Gestao@A3_2026', CHECK_POLICY = ON, DEFAULT_DATABASE = CadernetaDigital;
GO

USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'app_caderneta')
    CREATE USER app_caderneta FOR LOGIN app_caderneta;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'gestao_leitura')
    CREATE USER gestao_leitura FOR LOGIN gestao_leitura;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'papel_aplicacao' AND type = 'R')
    CREATE ROLE papel_aplicacao;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'papel_relatorio' AND type = 'R')
    CREATE ROLE papel_relatorio;
GO

/* Aplicação: lê e grava nos schemas de negócio, executa procedures/funções */
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::cadastro    TO papel_aplicacao;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::clinico     TO papel_aplicacao;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::atendimento TO papel_aplicacao;
GRANT SELECT                         ON SCHEMA::dominio     TO papel_aplicacao;
GRANT SELECT                         ON SCHEMA::relatorio   TO papel_aplicacao;
GRANT EXECUTE                        ON SCHEMA::cadastro    TO papel_aplicacao;
GRANT EXECUTE                        ON SCHEMA::clinico     TO papel_aplicacao;
GRANT EXECUTE                        ON SCHEMA::atendimento TO papel_aplicacao;
GRANT EXECUTE                        ON SCHEMA::relatorio   TO papel_aplicacao;
-- login: lê usuário/perfil e atualiza a data do último acesso
GRANT SELECT                         ON SCHEMA::seguranca   TO papel_aplicacao;
GRANT UPDATE (ultimo_acesso)         ON seguranca.usuario   TO papel_aplicacao;
-- auditoria: pode LER o log, mas nunca alterar ou apagar (só os triggers escrevem)
GRANT SELECT                         ON SCHEMA::auditoria   TO papel_aplicacao;
DENY  UPDATE, DELETE                 ON SCHEMA::auditoria   TO papel_aplicacao;
GO

/* Gestão (ex.: Power BI/Excel da secretaria): só leitura de relatórios e domínios */
GRANT SELECT  ON SCHEMA::relatorio TO papel_relatorio;
GRANT EXECUTE ON SCHEMA::relatorio TO papel_relatorio;
GRANT SELECT  ON SCHEMA::dominio   TO papel_relatorio;
DENY  SELECT  ON SCHEMA::seguranca TO papel_relatorio;   -- nunca vê hashes de senha
GO

ALTER ROLE papel_aplicacao ADD MEMBER app_caderneta;
ALTER ROLE papel_relatorio ADD MEMBER gestao_leitura;
GO

/* Conferência: permissões efetivas de cada role */
SELECT dp.name AS role, p.permission_name, p.state_desc, p.class_desc,
       CASE p.class_desc WHEN 'SCHEMA' THEN SCHEMA_NAME(p.major_id)
            ELSE CONCAT(OBJECT_SCHEMA_NAME(p.major_id), '.', OBJECT_NAME(p.major_id)) END AS alvo
FROM sys.database_permissions p
JOIN sys.database_principals  dp ON dp.principal_id = p.grantee_principal_id
WHERE dp.name IN (N'papel_aplicacao', N'papel_relatorio')
ORDER BY dp.name, alvo, p.permission_name;
GO
