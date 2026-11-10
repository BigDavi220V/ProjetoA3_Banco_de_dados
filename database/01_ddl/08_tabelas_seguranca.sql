/* =====================================================================
   08_tabelas_seguranca.sql  —  DDL: perfis, usuários e auditoria
   ---------------------------------------------------------------------
   - usuario guarda o HASH bcrypt da senha (nunca a senha em texto).
   - log_auditoria é escrito pelos triggers (ver 02_programabilidade/
     04_triggers.sql) e guarda o "antes" e o "depois" em JSON.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

CREATE TABLE seguranca.perfil (
    perfil_id  INT IDENTITY(1,1) NOT NULL,
    codigo     VARCHAR(20)       NOT NULL,
    nome       NVARCHAR(60)      NOT NULL,
    descricao  NVARCHAR(200)     NULL,
    CONSTRAINT pk_perfil        PRIMARY KEY (perfil_id),
    CONSTRAINT uq_perfil_codigo UNIQUE (codigo),
    CONSTRAINT ck_perfil_codigo CHECK (codigo IN ('RECEPCAO','ENFERMAGEM','MEDICO','GESTOR'))
);
GO

CREATE TABLE seguranca.usuario (
    usuario_id       INT IDENTITY(1,1) NOT NULL,
    login            VARCHAR(80)       NOT NULL,
    senha_hash       CHAR(60)          NOT NULL,   -- bcrypt sempre tem 60 caracteres
    perfil_id        INT               NOT NULL,
    profissional_id  INT               NULL,       -- recepção/gestão podem não ser profissionais de saúde
    nome_exibicao    NVARCHAR(80)      NOT NULL,
    ativo            BIT               NOT NULL CONSTRAINT df_usuario_ativo DEFAULT (1),
    ultimo_acesso    DATETIME2(0)      NULL,
    criado_em        DATETIME2(0)      NOT NULL CONSTRAINT df_usuario_criado DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_usuario              PRIMARY KEY (usuario_id),
    CONSTRAINT uq_usuario_login        UNIQUE (login),
    CONSTRAINT fk_usuario_perfil       FOREIGN KEY (perfil_id)       REFERENCES seguranca.perfil (perfil_id),
    CONSTRAINT fk_usuario_profissional FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id),
    CONSTRAINT ck_usuario_hash         CHECK (senha_hash LIKE '$2[aby]$%')
);
GO
-- Um profissional tem no máximo um usuário (1:1 opcional)
CREATE UNIQUE INDEX uq_usuario_profissional ON seguranca.usuario (profissional_id) WHERE profissional_id IS NOT NULL;
GO

/* Log de auditoria. Sem FK de propósito: o log precisa sobreviver
   mesmo se o registro original ou o usuário for apagado. */
CREATE TABLE auditoria.log_auditoria (
    log_id        BIGINT IDENTITY(1,1) NOT NULL,
    tabela        SYSNAME              NOT NULL,
    operacao      CHAR(1)              NOT NULL,   -- I = insert, U = update, D = delete
    chave         NVARCHAR(50)         NOT NULL,   -- id do registro afetado
    usuario_id    INT                  NULL,       -- vem do SESSION_CONTEXT setado pela API
    dados_antes   NVARCHAR(MAX)        NULL,
    dados_depois  NVARCHAR(MAX)        NULL,
    data_hora     DATETIME2(3)         NOT NULL CONSTRAINT df_log_data DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_log_auditoria   PRIMARY KEY (log_id),
    CONSTRAINT ck_log_operacao    CHECK (operacao IN ('I','U','D')),
    CONSTRAINT ck_log_json_antes  CHECK (dados_antes  IS NULL OR ISJSON(dados_antes)  = 1),
    CONSTRAINT ck_log_json_depois CHECK (dados_depois IS NULL OR ISJSON(dados_depois) = 1)
);
GO
PRINT 'Tabelas de segurança e auditoria criadas.';
GO
