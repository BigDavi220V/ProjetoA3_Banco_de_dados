/* =====================================================================
   02_create_schemas.sql  —  DDL: schemas (a "arquitetura" do banco)
   ---------------------------------------------------------------------
   Um schema é uma "pasta" dentro do banco. Separamos as tabelas por
   assunto (domínio), igual a separar o backend em pastas:

     dominio      -> listas fixas (catálogos): vacinas, agravos CID-10,
                     tipos de triagem, sinais de alerta, setores...
     cadastro     -> quem é quem: unidades, profissionais, gestantes,
                     crianças, telefones
     clinico      -> o que aconteceu com a criança: pré-natal, parto,
                     nascimento, internação, alta, triagens neonatais
     atendimento  -> agenda, consultas, vacinas aplicadas
     seguranca    -> perfis e usuários do sistema
     auditoria    -> log de alterações (preenchido por triggers)
     relatorio    -> views e procedures de gestão (somente leitura)

   Vantagem: permissões por schema (ver 05_dcl) e leitura fácil do DER.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

IF SCHEMA_ID(N'dominio')     IS NULL EXEC (N'CREATE SCHEMA dominio');
IF SCHEMA_ID(N'cadastro')    IS NULL EXEC (N'CREATE SCHEMA cadastro');
IF SCHEMA_ID(N'clinico')     IS NULL EXEC (N'CREATE SCHEMA clinico');
IF SCHEMA_ID(N'atendimento') IS NULL EXEC (N'CREATE SCHEMA atendimento');
IF SCHEMA_ID(N'seguranca')   IS NULL EXEC (N'CREATE SCHEMA seguranca');
IF SCHEMA_ID(N'auditoria')   IS NULL EXEC (N'CREATE SCHEMA auditoria');
IF SCHEMA_ID(N'relatorio')   IS NULL EXEC (N'CREATE SCHEMA relatorio');
GO
-- (CREATE SCHEMA precisa ser o único comando do lote; por isso o EXEC)
PRINT 'Schemas prontos.';
GO
