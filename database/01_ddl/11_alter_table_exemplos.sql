/* =====================================================================
   11_alter_table_exemplos.sql  —  DDL: ALTER TABLE (evolução do esquema)
   ---------------------------------------------------------------------
   Simula mudanças pedidas DEPOIS que o banco já existia — situação
   comum na vida real. Cada bloco verifica antes se a mudança já foi
   aplicada, então o script pode rodar mais de uma vez sem erro.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* 1) ADD COLUMN: a rede pediu para registrar o "nome social" da gestante */
IF COL_LENGTH('cadastro.gestante', 'nome_social') IS NULL
    ALTER TABLE cadastro.gestante ADD nome_social NVARCHAR(150) NULL;
GO

/* 2) ADD CONSTRAINT: e-mail do profissional passa a ser único quando informado */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'uq_profissional_email')
    CREATE UNIQUE INDEX uq_profissional_email ON cadastro.profissional (email) WHERE email IS NOT NULL;
GO

/* 3) ADD COLUMN com DEFAULT: canal de origem do agendamento (para medir uso do sistema) */
IF COL_LENGTH('atendimento.agendamento', 'canal') IS NULL
    ALTER TABLE atendimento.agendamento
        ADD canal VARCHAR(10) NOT NULL
            CONSTRAINT df_agendamento_canal DEFAULT ('SISTEMA')
            CONSTRAINT ck_agendamento_canal CHECK (canal IN ('SISTEMA','TELEFONE','BALCAO'));
GO

/* 4) ALTER COLUMN: observação da gestação ficou pequena (300 -> 500) */
ALTER TABLE clinico.gestacao ALTER COLUMN observacao NVARCHAR(500) NULL;
GO

/* 5) Nova regra: o Apgar do 5º minuto só pode ser informado junto com o do 1º
      (CHECK adicionado depois; WITH CHECK = também valida os dados que já existem) */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'ck_nascimento_apgar_ordem')
    ALTER TABLE clinico.nascimento WITH CHECK
        ADD CONSTRAINT ck_nascimento_apgar_ordem
        CHECK (apgar_5min IS NULL OR apgar_1min IS NOT NULL);  -- 5º min só depois do 1º
GO
PRINT 'Alterações de esquema aplicadas.';
GO
