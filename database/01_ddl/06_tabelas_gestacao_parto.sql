/* =====================================================================
   06_tabelas_gestacao_parto.sql  —  DDL: Anexo I.b (1ª parte)
   "Pré-Natal, Parto, Nascimento..."
   ---------------------------------------------------------------------
   GESTAÇÃO é o "eixo" do modelo: a gestante tem 1..N gestações, cada
   gestação tem 0..1 parto e gera 1..N crianças (gêmeos = gravidez múltipla).
   Assim a criança NÃO guarda a mãe diretamente (evita dependência
   transitiva): criança -> gestação -> gestante.

   O quadro de SOROLOGIAS do papel é uma GRADE (agravo x trimestre).
   Em papel isso são 12 "colunas repetidas" — viola a 1FN. Aqui cada
   célula da grade vira UMA LINHA de sorologia_prenatal.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

CREATE TABLE clinico.gestacao (
    gestacao_id       INT IDENTITY(1,1) NOT NULL,
    gestante_id       INT               NOT NULL,
    data_registro     DATE              NOT NULL CONSTRAINT df_gestacao_registro DEFAULT (CAST(SYSDATETIME() AS DATE)),
    dum               DATE              NULL,   -- data da última menstruação
    planejada         BIT               NULL,   -- NULL = não informado
    fez_prenatal      BIT               NULL,
    numero_consultas  TINYINT           NULL,
    trimestre_inicio  TINYINT           NULL,
    tipo_gravidez     VARCHAR(8)        NULL,
    gravidez_risco    BIT               NULL,
    risco_descricao   NVARCHAR(200)     NULL,
    coombs_indireto   VARCHAR(13)       NULL,   -- exame da MÃE (CI do formulário)
    observacao        NVARCHAR(300)     NULL,
    CONSTRAINT pk_gestacao            PRIMARY KEY (gestacao_id),
    CONSTRAINT fk_gestacao_gestante   FOREIGN KEY (gestante_id) REFERENCES cadastro.gestante (gestante_id),
    CONSTRAINT ck_gestacao_consultas  CHECK (numero_consultas IS NULL OR numero_consultas BETWEEN 0 AND 40),
    CONSTRAINT ck_gestacao_trimestre  CHECK (trimestre_inicio IS NULL OR trimestre_inicio BETWEEN 1 AND 3),
    CONSTRAINT ck_gestacao_tipo       CHECK (tipo_gravidez IS NULL OR tipo_gravidez IN ('UNICA','MULTIPLA')),
    CONSTRAINT ck_gestacao_coombs     CHECK (coombs_indireto IS NULL OR coombs_indireto IN ('POSITIVO','NEGATIVO','NAO_REALIZADO')),
    -- Regra de negócio: quem NÃO fez pré-natal não tem consultas nem trimestre de início
    CONSTRAINT ck_gestacao_prenatal   CHECK (fez_prenatal IS NULL OR fez_prenatal = 1
                                          OR (ISNULL(numero_consultas, 0) = 0 AND trimestre_inicio IS NULL)),
    -- Regra de negócio: gravidez de risco exige dizer "qual?"
    CONSTRAINT ck_gestacao_risco      CHECK (ISNULL(gravidez_risco, 0) = 0 OR risco_descricao IS NOT NULL)
);
GO

/* Cada célula da grade "Sorologias x Trimestre" do papel = 1 linha.
   PK composta: (gestação, agravo, trimestre) -> não deixa lançar a
   mesma sorologia duas vezes no mesmo trimestre. */
CREATE TABLE clinico.sorologia_prenatal (
    gestacao_id  INT     NOT NULL,
    agravo_id    INT     NOT NULL,
    trimestre    TINYINT NOT NULL,
    resultado    VARCHAR(3) NOT NULL,  -- NR = não realizado, N = normal, ALT = alterado
    data_exame   DATE    NULL,
    CONSTRAINT pk_sorologia_prenatal PRIMARY KEY (gestacao_id, agravo_id, trimestre),
    CONSTRAINT fk_sorologia_gestacao FOREIGN KEY (gestacao_id) REFERENCES clinico.gestacao (gestacao_id) ON DELETE CASCADE,
    CONSTRAINT fk_sorologia_agravo   FOREIGN KEY (agravo_id)   REFERENCES dominio.agravo (agravo_id),
    CONSTRAINT ck_sorologia_trimestre CHECK (trimestre BETWEEN 1 AND 3),
    CONSTRAINT ck_sorologia_resultado CHECK (resultado IN ('NR','N','ALT')),
    CONSTRAINT ck_sorologia_data      CHECK (resultado <> 'NR' OR data_exame IS NULL)
);
GO

/* Quadro "Vacinas no pré-natal" (dTpa, Influenza, Hepatite B, Covid-19) */
CREATE TABLE clinico.vacina_prenatal (
    gestacao_id  INT NOT NULL,
    vacina_id    INT NOT NULL,
    recebeu      BIT NOT NULL,
    CONSTRAINT pk_vacina_prenatal          PRIMARY KEY (gestacao_id, vacina_id),
    CONSTRAINT fk_vacina_prenatal_gestacao FOREIGN KEY (gestacao_id) REFERENCES clinico.gestacao (gestacao_id) ON DELETE CASCADE,
    CONSTRAINT fk_vacina_prenatal_vacina   FOREIGN KEY (vacina_id)   REFERENCES dominio.vacina (vacina_id)
);
GO

/* Parto: 1 gestação -> no máximo 1 parto (UNIQUE na FK = relacionamento 1:1) */
CREATE TABLE clinico.parto (
    parto_id                INT IDENTITY(1,1) NOT NULL,
    gestacao_id             INT               NOT NULL,
    data_parto              DATE              NOT NULL,
    local_tipo              VARCHAR(20)       NOT NULL,
    unidade_id              INT               NULL,   -- maternidade / centro de parto da rede
    local_descricao         NVARCHAR(150)     NULL,   -- quando é "Outro" ou fora da rede
    tipo_parto              VARCHAR(8)        NOT NULL,
    motivo_cesarea          NVARCHAR(200)     NULL,
    teve_acompanhante       BIT               NULL,
    acompanhante_descricao  NVARCHAR(100)     NULL,
    CONSTRAINT pk_parto             PRIMARY KEY (parto_id),
    CONSTRAINT uq_parto_gestacao    UNIQUE (gestacao_id),
    CONSTRAINT fk_parto_gestacao    FOREIGN KEY (gestacao_id) REFERENCES clinico.gestacao (gestacao_id),
    CONSTRAINT fk_parto_unidade     FOREIGN KEY (unidade_id)  REFERENCES cadastro.unidade_saude (unidade_id),
    CONSTRAINT ck_parto_local       CHECK (local_tipo IN ('HOSPITAL','CENTRO_PARTO_NORMAL','DOMICILIO','OUTRO')),
    CONSTRAINT ck_parto_local_outro CHECK (local_tipo <> 'OUTRO' OR local_descricao IS NOT NULL),
    CONSTRAINT ck_parto_tipo        CHECK (tipo_parto IN ('VAGINAL','CESAREA')),
    -- Regra: cesárea exige motivo
    CONSTRAINT ck_parto_cesarea     CHECK (tipo_parto <> 'CESAREA' OR motivo_cesarea IS NOT NULL)
);
GO
PRINT 'Tabelas de gestação e parto criadas.';
GO
