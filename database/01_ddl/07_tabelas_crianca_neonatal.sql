/* =====================================================================
   07_tabelas_crianca_neonatal.sql  —  DDL: criança, prontuário,
   nascimento, internação, alta (Anexo I.b) e triagens (Anexo I.a)
   ---------------------------------------------------------------------
   Decisões de normalização:
   - Tipo sanguíneo da MÃE fica em gestante; o do BEBÊ fica em criança.
     Coombs indireto (mãe) fica em gestação; Coombs direto (bebê) fica
     em nascimento. Cada dado depende só da chave da sua tabela (3FN).
   - "Adequação peso/IG" (AIG/PIG/GIG) NÃO é armazenada: é DERIVADA de
     peso + IG + sexo (função clinico.fn_classificar_peso_ig). Guardar
     geraria dependência transitiva e risco de inconsistência.
   - Internação pode passar por VÁRIOS setores (UTIN 5 dias, depois
     UCINCo 3 dias...) -> tabela internacao_setor.
   - Triagens: olhinho e orelhinha têm resultado POR LADO (D/E) ->
     triagem_resultado_lado. O coraçãozinho guarda as aferições de
     saturação e o resultado é calculado pela regra do Ministério.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

CREATE TABLE cadastro.crianca (
    crianca_id             INT IDENTITY(1,1) NOT NULL,
    gestacao_id            INT               NOT NULL,
    nome                   NVARCHAR(150)     NOT NULL,
    sexo                   CHAR(1)           NOT NULL,
    data_nascimento        DATE              NOT NULL,
    cns                    CHAR(15)          NULL,
    tipo_sanguineo         VARCHAR(2)        NULL,
    fator_rh               CHAR(1)           NULL,
    unidade_referencia_id  INT               NOT NULL,   -- UBS/USF que acompanha a criança
    ativo                  BIT               NOT NULL CONSTRAINT df_crianca_ativo DEFAULT (1),
    inativado_em           DATETIME2(0)      NULL,
    motivo_inativacao      NVARCHAR(200)     NULL,
    criado_em              DATETIME2(0)      NOT NULL CONSTRAINT df_crianca_criado DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_crianca              PRIMARY KEY (crianca_id),
    CONSTRAINT fk_crianca_gestacao     FOREIGN KEY (gestacao_id)           REFERENCES clinico.gestacao (gestacao_id),
    CONSTRAINT fk_crianca_unidade      FOREIGN KEY (unidade_referencia_id) REFERENCES cadastro.unidade_saude (unidade_id),
    CONSTRAINT ck_crianca_sexo         CHECK (sexo IN ('M','F','I')),   -- I = indeterminado
    CONSTRAINT ck_crianca_nascimento   CHECK (data_nascimento <= CAST(GETDATE() AS DATE)),
    CONSTRAINT ck_crianca_cns          CHECK (cns IS NULL OR cns NOT LIKE '%[^0-9]%'),
    CONSTRAINT ck_crianca_tipo_sang    CHECK (tipo_sanguineo IS NULL OR tipo_sanguineo IN ('A','B','AB','O')),
    CONSTRAINT ck_crianca_rh           CHECK (fator_rh IS NULL OR fator_rh IN ('+','-')),
    -- Inativação lógica: se ativo = 0, precisa de data e motivo
    CONSTRAINT ck_crianca_inativacao   CHECK (ativo = 1 OR (inativado_em IS NOT NULL AND motivo_inativacao IS NOT NULL))
);
GO
CREATE UNIQUE INDEX uq_crianca_cns ON cadastro.crianca (cns) WHERE cns IS NOT NULL;
GO

/* Prontuário (edital: entidade "Prontuário"). Número gerado por SEQUENCE.
   Aberto automaticamente pelo trigger trg_crianca_abrir_prontuario. */
CREATE SEQUENCE clinico.seq_prontuario AS INT START WITH 1 INCREMENT BY 1;
GO
CREATE TABLE clinico.prontuario (
    prontuario_id  INT IDENTITY(1,1) NOT NULL,
    numero         VARCHAR(12)       NOT NULL
        CONSTRAINT df_prontuario_numero DEFAULT ('CC-' + RIGHT('000000' + CAST(NEXT VALUE FOR clinico.seq_prontuario AS VARCHAR(10)), 6)),
    crianca_id     INT               NOT NULL,
    unidade_id     INT               NOT NULL,
    data_abertura  DATE              NOT NULL CONSTRAINT df_prontuario_abertura DEFAULT (CAST(SYSDATETIME() AS DATE)),
    CONSTRAINT pk_prontuario         PRIMARY KEY (prontuario_id),
    CONSTRAINT uq_prontuario_numero  UNIQUE (numero),
    CONSTRAINT uq_prontuario_crianca UNIQUE (crianca_id),           -- 1 criança = 1 prontuário (1:1)
    CONSTRAINT fk_prontuario_crianca FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE,
    CONSTRAINT fk_prontuario_unidade FOREIGN KEY (unidade_id) REFERENCES cadastro.unidade_saude (unidade_id)
);
GO

/* Dados do nascimento (um por criança). O parto é da GESTAÇÃO;
   o nascimento é de CADA BEBÊ (gêmeos = 1 parto, 2 nascimentos). */
CREATE TABLE clinico.nascimento (
    nascimento_id          INT IDENTITY(1,1) NOT NULL,
    crianca_id             INT               NOT NULL,
    hora_nascimento        TIME(0)           NULL,
    contato_pele_a_pele    BIT               NULL,
    mamou_primeira_hora    BIT               NULL,
    apgar_1min             TINYINT           NULL,
    apgar_5min             TINYINT           NULL,
    clampeamento_oportuno  BIT               NULL,
    ig_semanas             TINYINT           NULL,
    ig_dias                TINYINT           NULL,
    ig_metodo              VARCHAR(10)       NULL,
    ig_metodo_descricao    NVARCHAR(100)     NULL,
    peso_g                 SMALLINT          NULL,
    comprimento_cm         DECIMAL(4,1)      NULL,
    perimetro_cefalico_cm  DECIMAL(4,1)      NULL,
    reanimacao             BIT               NULL,
    assistido_por_id       INT               NULL,   -- profissional que assistiu o RN no parto
    coombs_direto          VARCHAR(13)       NULL,
    profilaxia_oftalmica   BIT               NULL,
    vitamina_k             BIT               NULL,
    registrado_por_id      INT               NULL,
    registrado_em          DATETIME2(0)      NOT NULL CONSTRAINT df_nascimento_registro DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_nascimento             PRIMARY KEY (nascimento_id),
    CONSTRAINT uq_nascimento_crianca     UNIQUE (crianca_id),
    CONSTRAINT fk_nascimento_crianca     FOREIGN KEY (crianca_id)        REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE,
    CONSTRAINT fk_nascimento_assistido   FOREIGN KEY (assistido_por_id)  REFERENCES cadastro.profissional (profissional_id),
    CONSTRAINT fk_nascimento_registrado  FOREIGN KEY (registrado_por_id) REFERENCES cadastro.profissional (profissional_id),
    CONSTRAINT ck_nascimento_apgar1      CHECK (apgar_1min IS NULL OR apgar_1min BETWEEN 0 AND 10),
    CONSTRAINT ck_nascimento_apgar5      CHECK (apgar_5min IS NULL OR apgar_5min BETWEEN 0 AND 10),
    CONSTRAINT ck_nascimento_ig_semanas  CHECK (ig_semanas IS NULL OR ig_semanas BETWEEN 22 AND 44),
    CONSTRAINT ck_nascimento_ig_dias     CHECK (ig_dias IS NULL OR ig_dias BETWEEN 0 AND 6),
    CONSTRAINT ck_nascimento_ig_metodo   CHECK (ig_metodo IS NULL OR ig_metodo IN ('DUM','USG','EXAME_RN','OUTRO')),
    CONSTRAINT ck_nascimento_metodo_outro CHECK (ISNULL(ig_metodo,'') <> 'OUTRO' OR ig_metodo_descricao IS NOT NULL),
    CONSTRAINT ck_nascimento_peso        CHECK (peso_g IS NULL OR peso_g BETWEEN 300 AND 7000),
    CONSTRAINT ck_nascimento_comprimento CHECK (comprimento_cm IS NULL OR comprimento_cm BETWEEN 25 AND 65),
    CONSTRAINT ck_nascimento_pc          CHECK (perimetro_cefalico_cm IS NULL OR perimetro_cefalico_cm BETWEEN 20 AND 45),
    CONSTRAINT ck_nascimento_coombs      CHECK (coombs_direto IS NULL OR coombs_direto IN ('POSITIVO','NEGATIVO','NAO_REALIZADO'))
);
GO

/* Internação neonatal (só existe se o bebê foi internado) */
CREATE TABLE clinico.internacao_neonatal (
    internacao_id  INT IDENTITY(1,1) NOT NULL,
    crianca_id     INT               NOT NULL,
    motivo         NVARCHAR(300)     NOT NULL,
    data_inicio    DATE              NULL,
    CONSTRAINT pk_internacao_neonatal  PRIMARY KEY (internacao_id),
    CONSTRAINT uq_internacao_crianca   UNIQUE (crianca_id),
    CONSTRAINT fk_internacao_crianca   FOREIGN KEY (crianca_id) REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE
);
GO

/* "Onde? ( ) UTIN __ dias ( ) UCINCo __ dias ..." -> multivalorado */
CREATE TABLE clinico.internacao_setor (
    internacao_id  INT      NOT NULL,
    setor_id       INT      NOT NULL,
    dias           SMALLINT NOT NULL,
    CONSTRAINT pk_internacao_setor        PRIMARY KEY (internacao_id, setor_id),
    CONSTRAINT fk_intsetor_internacao     FOREIGN KEY (internacao_id) REFERENCES clinico.internacao_neonatal (internacao_id) ON DELETE CASCADE,
    CONSTRAINT fk_intsetor_setor          FOREIGN KEY (setor_id)      REFERENCES dominio.setor_internacao (setor_id),
    CONSTRAINT ck_intsetor_dias           CHECK (dias BETWEEN 1 AND 365)
);
GO

/* Alta da maternidade (bloco final do Anexo I.b) */
CREATE TABLE clinico.alta_maternidade (
    alta_id              INT IDENTITY(1,1) NOT NULL,
    crianca_id           INT               NOT NULL,
    data_alta            DATE              NOT NULL,
    peso_alta_g          SMALLINT          NULL,
    comprimento_alta_cm  DECIMAL(4,1)      NULL,
    aleitamento          VARCHAR(5)        NULL,   -- LME | LM_LA | LA
    resumo_alta          NVARCHAR(1000)    NULL,   -- problemas, diagnósticos, tratamentos, recomendações
    registrado_por_id    INT               NULL,
    CONSTRAINT pk_alta_maternidade     PRIMARY KEY (alta_id),
    CONSTRAINT uq_alta_crianca         UNIQUE (crianca_id),
    CONSTRAINT fk_alta_crianca         FOREIGN KEY (crianca_id)        REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE,
    CONSTRAINT fk_alta_registrado      FOREIGN KEY (registrado_por_id) REFERENCES cadastro.profissional (profissional_id),
    CONSTRAINT ck_alta_peso            CHECK (peso_alta_g IS NULL OR peso_alta_g BETWEEN 300 AND 7000),
    CONSTRAINT ck_alta_comprimento     CHECK (comprimento_alta_cm IS NULL OR comprimento_alta_cm BETWEEN 25 AND 65),
    CONSTRAINT ck_alta_aleitamento     CHECK (aleitamento IS NULL OR aleitamento IN ('LME','LM_LA','LA'))
);
GO

/* Triagens neonatais: 1 registro por criança e por tipo de teste */
CREATE TABLE clinico.triagem_neonatal (
    triagem_id       INT IDENTITY(1,1) NOT NULL,
    crianca_id       INT               NOT NULL,
    tipo_triagem_id  INT               NOT NULL,
    realizada        BIT               NOT NULL,
    data_realizacao  DATE              NULL,
    metodo           VARCHAR(5)        NULL,     -- orelhinha: EOA ou PEATE
    data_reteste     DATE              NULL,     -- pezinho
    conduta          NVARCHAR(300)     NULL,     -- observação / encaminhamento
    profissional_id  INT               NULL,
    registrado_em    DATETIME2(0)      NOT NULL CONSTRAINT df_triagem_registro DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_triagem_neonatal   PRIMARY KEY (triagem_id),
    CONSTRAINT uq_triagem_crianca_tipo UNIQUE (crianca_id, tipo_triagem_id),
    CONSTRAINT fk_triagem_crianca    FOREIGN KEY (crianca_id)      REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE,
    CONSTRAINT fk_triagem_tipo       FOREIGN KEY (tipo_triagem_id) REFERENCES dominio.tipo_triagem (tipo_triagem_id),
    CONSTRAINT fk_triagem_profissional FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id),
    -- Realizada <=> tem data
    CONSTRAINT ck_triagem_data       CHECK ((realizada = 1 AND data_realizacao IS NOT NULL)
                                         OR (realizada = 0 AND data_realizacao IS NULL)),
    CONSTRAINT ck_triagem_metodo     CHECK (metodo IS NULL OR metodo IN ('EOA','PEATE')),
    CONSTRAINT ck_triagem_reteste    CHECK (data_reteste IS NULL OR data_reteste >= data_realizacao)
);
GO

/* Resultado por lado (olho/ouvido direito e esquerdo) */
CREATE TABLE clinico.triagem_resultado_lado (
    triagem_id  INT        NOT NULL,
    lado        CHAR(1)    NOT NULL,   -- D = direito, E = esquerdo
    resultado   VARCHAR(8) NOT NULL,
    CONSTRAINT pk_triagem_resultado_lado PRIMARY KEY (triagem_id, lado),
    CONSTRAINT fk_resultado_lado_triagem FOREIGN KEY (triagem_id) REFERENCES clinico.triagem_neonatal (triagem_id) ON DELETE CASCADE,
    CONSTRAINT ck_resultado_lado         CHECK (lado IN ('D','E')),
    CONSTRAINT ck_resultado_lado_valor   CHECK (resultado IN ('NORMAL','ALTERADO'))
);
GO

/* Teste do coraçãozinho: saturação na mão direita (pré-ductal) e no pé
   (pós-ductal). Se a 1ª aferição alterar, repete após 1 hora (2ª aferição). */
CREATE TABLE clinico.oximetria_afericao (
    triagem_id         INT     NOT NULL,
    numero_afericao    TINYINT NOT NULL,
    spo2_mao_direita   TINYINT NOT NULL,
    spo2_pe            TINYINT NOT NULL,
    aferido_em         DATETIME2(0) NULL,
    CONSTRAINT pk_oximetria_afericao PRIMARY KEY (triagem_id, numero_afericao),
    CONSTRAINT fk_oximetria_triagem  FOREIGN KEY (triagem_id) REFERENCES clinico.triagem_neonatal (triagem_id) ON DELETE CASCADE,
    CONSTRAINT ck_oximetria_numero   CHECK (numero_afericao IN (1,2)),
    CONSTRAINT ck_oximetria_mao      CHECK (spo2_mao_direita BETWEEN 50 AND 100),
    CONSTRAINT ck_oximetria_pe       CHECK (spo2_pe BETWEEN 50 AND 100)
);
GO
PRINT 'Tabelas da criança e período neonatal criadas.';
GO
