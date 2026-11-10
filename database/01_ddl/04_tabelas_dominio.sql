/* =====================================================================
   04_tabelas_dominio.sql  —  DDL: tabelas de domínio (catálogos)
   ---------------------------------------------------------------------
   São as "listas de opções" dos formulários em papel. Em vez de escrever
   "Hepatite B" em cada registro (texto repetido = redundância), guardamos
   uma vez aqui e os outros registros apontam pelo ID (FK).
   Convenções de nome usadas em TODO o banco:
     pk_<tabela>            chave primária
     fk_<filha>_<mãe>       chave estrangeira
     uq_<tabela>_<coluna>   unicidade
     ck_<tabela>_<regra>    validação (CHECK)
     df_<tabela>_<coluna>   valor padrão (DEFAULT)
     ix_<tabela>_<coluna>   índice de busca
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* Especialidades (edital: entidade "Especialidade") */
CREATE TABLE dominio.especialidade (
    especialidade_id  INT IDENTITY(1,1) NOT NULL,
    nome              NVARCHAR(80)      NOT NULL,
    descricao         NVARCHAR(255)     NULL,
    CONSTRAINT pk_especialidade      PRIMARY KEY (especialidade_id),
    CONSTRAINT uq_especialidade_nome UNIQUE (nome)
);
GO

/* Categoria profissional e o conselho que a regula */
CREATE TABLE dominio.categoria_profissional (
    categoria_id  INT IDENTITY(1,1) NOT NULL,
    nome          NVARCHAR(60)      NOT NULL,
    conselho      VARCHAR(6)        NOT NULL,
    pode_assinar_clinico BIT        NOT NULL CONSTRAINT df_categoria_assina DEFAULT (1),
    CONSTRAINT pk_categoria_profissional PRIMARY KEY (categoria_id),
    CONSTRAINT uq_categoria_nome         UNIQUE (nome),
    CONSTRAINT ck_categoria_conselho     CHECK (conselho IN ('CRM','COREN','CRFa','NENHUM'))
);
GO

/* Agravos pesquisados nas sorologias do pré-natal (código CID-10) */
CREATE TABLE dominio.agravo (
    agravo_id  INT IDENTITY(1,1) NOT NULL,
    cid10      VARCHAR(6)        NOT NULL,
    nome       NVARCHAR(100)     NOT NULL,
    CONSTRAINT pk_agravo        PRIMARY KEY (agravo_id),
    CONSTRAINT uq_agravo_cid10  UNIQUE (cid10),
    -- Formato CID-10: letra + 2 dígitos (+ subcategoria opcional). Ex.: A53, A92.5
    CONSTRAINT ck_agravo_cid10  CHECK (cid10 LIKE '[A-Z][0-9][0-9]%')
);
GO

/* Vacinas do pré-natal (gestante) e do recém-nascido */
CREATE TABLE dominio.vacina (
    vacina_id     INT IDENTITY(1,1) NOT NULL,
    sigla         VARCHAR(15)       NOT NULL,
    nome          NVARCHAR(100)     NOT NULL,
    publico_alvo  VARCHAR(8)        NOT NULL,
    CONSTRAINT pk_vacina         PRIMARY KEY (vacina_id),
    CONSTRAINT uq_vacina_sigla   UNIQUE (sigla),
    CONSTRAINT ck_vacina_publico CHECK (publico_alvo IN ('GESTANTE','CRIANCA','AMBOS'))
);
GO

/* Os 4 testes da triagem neonatal (olhinho, coraçãozinho, orelhinha, pezinho) */
CREATE TABLE dominio.tipo_triagem (
    tipo_triagem_id      INT IDENTITY(1,1) NOT NULL,
    codigo               VARCHAR(20)       NOT NULL,
    nome                 NVARCHAR(80)      NOT NULL,
    nome_popular         NVARCHAR(40)      NOT NULL,
    orientacao_prazo     NVARCHAR(200)     NOT NULL,
    prazo_max_dias       SMALLINT          NOT NULL,  -- após isso a triagem é considerada atrasada
    avalia_lateralidade  BIT               NOT NULL,  -- 1 = resultado por lado (olho/ouvido D e E)
    CONSTRAINT pk_tipo_triagem        PRIMARY KEY (tipo_triagem_id),
    CONSTRAINT uq_tipo_triagem_codigo UNIQUE (codigo),
    CONSTRAINT ck_tipo_triagem_prazo  CHECK (prazo_max_dias BETWEEN 1 AND 60)
);
GO

/* Sinais de alerta da Consulta da 1ª Semana */
CREATE TABLE dominio.sinal_alerta (
    sinal_alerta_id  INT IDENTITY(1,1) NOT NULL,
    nome             NVARCHAR(80)      NOT NULL,
    criterio         NVARCHAR(120)     NULL,
    ordem_exibicao   TINYINT           NOT NULL,
    CONSTRAINT pk_sinal_alerta      PRIMARY KEY (sinal_alerta_id),
    CONSTRAINT uq_sinal_alerta_nome UNIQUE (nome)
);
GO

/* Setores de internação neonatal: UTIN, UCINCo, UCINCa, Alojamento Conjunto */
CREATE TABLE dominio.setor_internacao (
    setor_id  INT IDENTITY(1,1) NOT NULL,
    sigla     VARCHAR(10)       NOT NULL,
    nome      NVARCHAR(100)     NOT NULL,
    CONSTRAINT pk_setor_internacao       PRIMARY KEY (setor_id),
    CONSTRAINT uq_setor_internacao_sigla UNIQUE (sigla)
);
GO

/* Tabela de referência para classificar peso x idade gestacional
   (AIG = adequado, PIG = pequeno, GIG = grande para a idade gestacional).
   Chave primária COMPOSTA: (semanas, sexo).
   Valores aproximados de percentis 10 e 90, apenas para fins acadêmicos. */
CREATE TABLE dominio.referencia_peso_ig (
    ig_semanas  TINYINT  NOT NULL,
    sexo        CHAR(1)  NOT NULL,
    p10_g       SMALLINT NOT NULL,
    p90_g       SMALLINT NOT NULL,
    CONSTRAINT pk_referencia_peso_ig PRIMARY KEY (ig_semanas, sexo),
    CONSTRAINT ck_ref_sexo           CHECK (sexo IN ('M','F')),
    CONSTRAINT ck_ref_faixa          CHECK (p10_g < p90_g),
    CONSTRAINT ck_ref_semanas        CHECK (ig_semanas BETWEEN 22 AND 44)
);
GO
PRINT 'Tabelas de domínio criadas.';
GO
