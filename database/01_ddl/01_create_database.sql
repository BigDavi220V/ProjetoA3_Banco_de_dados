/* =====================================================================
   01_create_database.sql  —  DDL: criação do banco
   ---------------------------------------------------------------------
   SGBD: Microsoft SQL Server 2019/2022 (T-SQL)
   Collation Latin1_General_CI_AI:
     CI = case insensitive  ("MARIA" = "maria")
     AI = accent insensitive ("Conceição" = "Conceicao") -> busca por nome
          funciona mesmo se a recepção digitar sem acento.
   ===================================================================== */
USE master;
GO

IF DB_ID(N'CadernetaDigital') IS NULL
BEGIN
    CREATE DATABASE CadernetaDigital COLLATE Latin1_General_CI_AI;
    PRINT 'Banco CadernetaDigital criado.';
END
ELSE
    PRINT 'Banco CadernetaDigital já existe (mantido).';
GO

USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

-- Formato de data esperado nos literais 'AAAA-MM-DD' e idioma das mensagens
SET DATEFORMAT ymd;
GO
