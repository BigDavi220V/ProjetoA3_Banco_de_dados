/* =====================================================================
   05_tabelas_cadastro.sql  —  DDL: unidades, profissionais, gestantes
   ---------------------------------------------------------------------
   Destaques para a banca:
   - ENDEREÇO é um atributo COMPOSTO no DER (logradouro, número, bairro...).
     No modelo físico ele vira várias colunas atômicas (1FN).
   - TELEFONE da gestante é MULTIVALORADO (uma mãe pode ter vários).
     Na 1FN ele sai da tabela e vira a tabela gestante_telefone.
   - Profissional x Especialidade é N:N -> tabela associativa
     profissional_especialidade com chave primária composta.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

CREATE TABLE cadastro.unidade_saude (
    unidade_id   INT IDENTITY(1,1) NOT NULL,
    cnes         CHAR(7)           NOT NULL,   -- Cadastro Nacional de Estabelecimentos de Saúde
    nome         NVARCHAR(120)     NOT NULL,
    tipo         VARCHAR(20)       NOT NULL,
    logradouro   NVARCHAR(120)     NOT NULL,
    numero       NVARCHAR(10)      NULL,
    bairro       NVARCHAR(60)      NOT NULL,
    municipio    NVARCHAR(60)      NOT NULL,
    uf           CHAR(2)           NOT NULL,
    telefone     VARCHAR(11)       NULL,
    ativo        BIT               NOT NULL CONSTRAINT df_unidade_ativo DEFAULT (1),
    CONSTRAINT pk_unidade_saude PRIMARY KEY (unidade_id),
    CONSTRAINT uq_unidade_cnes  UNIQUE (cnes),
    CONSTRAINT ck_unidade_cnes  CHECK (cnes NOT LIKE '%[^0-9]%'),
    CONSTRAINT ck_unidade_tipo  CHECK (tipo IN ('UBS','USF','MATERNIDADE','CENTRO_PARTO_NORMAL','HOSPITAL')),
    CONSTRAINT ck_unidade_uf    CHECK (uf LIKE '[A-Z][A-Z]')
);
GO

/* Edital: entidade "Médico". Generalizamos para PROFISSIONAL porque na
   caderneta registram médicos, enfermeiros, técnicos e fonoaudiólogos. */
CREATE TABLE cadastro.profissional (
    profissional_id    INT IDENTITY(1,1) NOT NULL,
    nome               NVARCHAR(150)     NOT NULL,
    cpf                CHAR(11)          NOT NULL,
    categoria_id       INT               NOT NULL,
    registro_conselho  VARCHAR(15)       NULL,      -- nº CRM / COREN / CRFa
    uf_conselho        CHAR(2)           NULL,
    unidade_id         INT               NOT NULL,  -- lotação principal
    email              VARCHAR(120)      NULL,
    ativo              BIT               NOT NULL CONSTRAINT df_profissional_ativo DEFAULT (1),
    criado_em          DATETIME2(0)      NOT NULL CONSTRAINT df_profissional_criado DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_profissional            PRIMARY KEY (profissional_id),
    CONSTRAINT uq_profissional_cpf        UNIQUE (cpf),
    CONSTRAINT fk_profissional_categoria  FOREIGN KEY (categoria_id) REFERENCES dominio.categoria_profissional (categoria_id),
    CONSTRAINT fk_profissional_unidade    FOREIGN KEY (unidade_id)   REFERENCES cadastro.unidade_saude (unidade_id),
    CONSTRAINT ck_profissional_cpf        CHECK (cpf NOT LIKE '%[^0-9]%'),
    -- Registro e UF do conselho andam juntos: ou os dois, ou nenhum
    CONSTRAINT ck_profissional_conselho   CHECK ((registro_conselho IS NULL AND uf_conselho IS NULL)
                                              OR (registro_conselho IS NOT NULL AND uf_conselho IS NOT NULL)),
    CONSTRAINT ck_profissional_email      CHECK (email IS NULL OR email LIKE '%_@_%._%')
);
GO

/* Tabela associativa N:N (um profissional pode ter várias especialidades) */
CREATE TABLE cadastro.profissional_especialidade (
    profissional_id   INT  NOT NULL,
    especialidade_id  INT  NOT NULL,
    data_titulo       DATE NULL,
    CONSTRAINT pk_profissional_especialidade PRIMARY KEY (profissional_id, especialidade_id),
    CONSTRAINT fk_profesp_profissional  FOREIGN KEY (profissional_id)  REFERENCES cadastro.profissional (profissional_id) ON DELETE CASCADE,
    CONSTRAINT fk_profesp_especialidade FOREIGN KEY (especialidade_id) REFERENCES dominio.especialidade (especialidade_id)
);
GO

/* Gestante / mãe da criança */
CREATE TABLE cadastro.gestante (
    gestante_id           INT IDENTITY(1,1) NOT NULL,
    nome                  NVARCHAR(150)     NOT NULL,
    cpf                   CHAR(11)          NULL,
    cns                   CHAR(15)          NULL,  -- Cartão Nacional de Saúde
    data_nascimento       DATE              NOT NULL,
    tipo_sanguineo        VARCHAR(2)        NULL,
    fator_rh              CHAR(1)           NULL,
    -- atributo composto ENDEREÇO -> colunas atômicas
    logradouro            NVARCHAR(120)     NULL,
    numero                NVARCHAR(10)      NULL,
    complemento           NVARCHAR(60)      NULL,
    bairro                NVARCHAR(60)      NULL,
    municipio             NVARCHAR(60)      NOT NULL CONSTRAINT df_gestante_municipio DEFAULT (N'Salvador'),
    uf                    CHAR(2)           NOT NULL CONSTRAINT df_gestante_uf DEFAULT ('BA'),
    cep                   CHAR(8)           NULL,
    unidade_referencia_id INT               NULL,
    criado_em             DATETIME2(0)      NOT NULL CONSTRAINT df_gestante_criado DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_gestante              PRIMARY KEY (gestante_id),
    CONSTRAINT fk_gestante_unidade      FOREIGN KEY (unidade_referencia_id) REFERENCES cadastro.unidade_saude (unidade_id),
    CONSTRAINT ck_gestante_documento    CHECK (cpf IS NOT NULL OR cns IS NOT NULL),
    CONSTRAINT ck_gestante_cpf          CHECK (cpf IS NULL OR cpf NOT LIKE '%[^0-9]%'),
    CONSTRAINT ck_gestante_cns          CHECK (cns IS NULL OR cns NOT LIKE '%[^0-9]%'),
    CONSTRAINT ck_gestante_tipo_sang    CHECK (tipo_sanguineo IS NULL OR tipo_sanguineo IN ('A','B','AB','O')),
    CONSTRAINT ck_gestante_rh           CHECK (fator_rh IS NULL OR fator_rh IN ('+','-')),
    CONSTRAINT ck_gestante_cep          CHECK (cep IS NULL OR cep NOT LIKE '%[^0-9]%'),
    CONSTRAINT ck_gestante_nascimento   CHECK (data_nascimento > '1950-01-01')
);
GO
-- CPF e CNS são opcionais, mas se preenchidos não podem repetir.
-- UNIQUE comum não aceitaria dois NULL -> usamos índice único FILTRADO.
CREATE UNIQUE INDEX uq_gestante_cpf ON cadastro.gestante (cpf) WHERE cpf IS NOT NULL;
CREATE UNIQUE INDEX uq_gestante_cns ON cadastro.gestante (cns) WHERE cns IS NOT NULL;
GO

/* Atributo MULTIVALORADO "telefones" virou tabela própria (1FN) */
CREATE TABLE cadastro.gestante_telefone (
    telefone_id  INT IDENTITY(1,1) NOT NULL,
    gestante_id  INT               NOT NULL,
    ddd          CHAR(2)           NOT NULL,
    numero       VARCHAR(9)        NOT NULL,
    tipo         VARCHAR(8)        NOT NULL CONSTRAINT df_telefone_tipo DEFAULT ('CELULAR'),
    whatsapp     BIT               NOT NULL CONSTRAINT df_telefone_whatsapp DEFAULT (0),
    CONSTRAINT pk_gestante_telefone  PRIMARY KEY (telefone_id),
    CONSTRAINT fk_telefone_gestante  FOREIGN KEY (gestante_id) REFERENCES cadastro.gestante (gestante_id) ON DELETE CASCADE,
    CONSTRAINT uq_telefone_gestante  UNIQUE (gestante_id, ddd, numero),
    CONSTRAINT ck_telefone_tipo      CHECK (tipo IN ('CELULAR','FIXO','RECADO')),
    CONSTRAINT ck_telefone_numero    CHECK (numero NOT LIKE '%[^0-9]%' AND LEN(numero) BETWEEN 8 AND 9),
    CONSTRAINT ck_telefone_ddd       CHECK (ddd LIKE '[1-9][0-9]')
);
GO
PRINT 'Tabelas de cadastro criadas.';
GO
