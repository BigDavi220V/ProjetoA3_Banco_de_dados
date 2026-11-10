/* =====================================================================
   09_tabelas_atendimento.sql  —  DDL: agenda, consultas e vacinas
   ---------------------------------------------------------------------
   Agendamento (o que foi marcado) é separado de Consulta (o que de fato
   aconteceu). Ligação 1:0..1: uma consulta pode ou não vir de um
   agendamento (ex.: visita domiciliar sem marcação).
   Consulta da 1ª Semana (Anexo I.a) = consulta com tipo PRIMEIRA_SEMANA.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

CREATE TABLE atendimento.agendamento (
    agendamento_id         INT IDENTITY(1,1) NOT NULL,
    crianca_id             INT               NOT NULL,
    profissional_id        INT               NOT NULL,
    especialidade_id       INT               NOT NULL,
    unidade_id             INT               NOT NULL,
    data_hora              DATETIME2(0)      NOT NULL,
    duracao_min            SMALLINT          NOT NULL CONSTRAINT df_agendamento_duracao DEFAULT (30),
    tipo_atendimento       VARCHAR(20)       NOT NULL,
    local_atendimento      VARCHAR(10)       NOT NULL CONSTRAINT df_agendamento_local DEFAULT ('UNIDADE'),
    status                 VARCHAR(10)       NOT NULL CONSTRAINT df_agendamento_status DEFAULT ('AGENDADO'),
    motivo_cancelamento    NVARCHAR(200)     NULL,
    observacao             NVARCHAR(200)     NULL,
    criado_por_usuario_id  INT               NULL,
    criado_em              DATETIME2(0)      NOT NULL CONSTRAINT df_agendamento_criado DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_agendamento               PRIMARY KEY (agendamento_id),
    CONSTRAINT fk_agendamento_crianca       FOREIGN KEY (crianca_id)       REFERENCES cadastro.crianca (crianca_id),
    CONSTRAINT fk_agendamento_profissional  FOREIGN KEY (profissional_id)  REFERENCES cadastro.profissional (profissional_id),
    CONSTRAINT fk_agendamento_especialidade FOREIGN KEY (especialidade_id) REFERENCES dominio.especialidade (especialidade_id),
    CONSTRAINT fk_agendamento_unidade       FOREIGN KEY (unidade_id)       REFERENCES cadastro.unidade_saude (unidade_id),
    CONSTRAINT fk_agendamento_usuario       FOREIGN KEY (criado_por_usuario_id) REFERENCES seguranca.usuario (usuario_id),
    CONSTRAINT ck_agendamento_duracao       CHECK (duracao_min BETWEEN 10 AND 120),
    CONSTRAINT ck_agendamento_tipo          CHECK (tipo_atendimento IN ('PRIMEIRA_SEMANA','PUERICULTURA','TRIAGEM','VACINA','VISITA_DOMICILIAR')),
    CONSTRAINT ck_agendamento_local         CHECK (local_atendimento IN ('UNIDADE','DOMICILIO')),
    CONSTRAINT ck_agendamento_status        CHECK (status IN ('AGENDADO','REALIZADO','CANCELADO','FALTOU')),
    -- Regra: cancelamento exige motivo (rastreabilidade)
    CONSTRAINT ck_agendamento_cancelado     CHECK (status <> 'CANCELADO' OR motivo_cancelamento IS NOT NULL)
);
GO
-- O mesmo profissional não pode ter dois agendamentos ATIVOS no mesmo horário.
-- Índice único filtrado: cancelados não contam.
CREATE UNIQUE INDEX uq_agendamento_profissional_horario
    ON atendimento.agendamento (profissional_id, data_hora)
    WHERE status = 'AGENDADO';
GO

/* Edital: entidade "Consulta". */
CREATE TABLE atendimento.consulta (
    consulta_id            INT IDENTITY(1,1) NOT NULL,
    crianca_id             INT               NOT NULL,
    profissional_id        INT               NOT NULL,
    especialidade_id       INT               NOT NULL,
    unidade_id             INT               NOT NULL,
    agendamento_id         INT               NULL,
    tipo_atendimento       VARCHAR(20)       NOT NULL,
    local_atendimento      VARCHAR(10)       NOT NULL CONSTRAINT df_consulta_local DEFAULT ('UNIDADE'),
    data_consulta          DATETIME2(0)      NOT NULL CONSTRAINT df_consulta_data DEFAULT (SYSDATETIME()),
    -- 1. Medidas
    peso_g                 SMALLINT          NULL,
    comprimento_cm         DECIMAL(4,1)      NULL,
    perimetro_cefalico_cm  DECIMAL(4,1)      NULL,
    -- 2. Aleitamento / alimentação
    aleitamento            VARCHAR(5)        NULL,
    aleitamento_observacao NVARCHAR(200)     NULL,
    dificuldade_amamentar  BIT               NULL,
    dificuldade_descricao  NVARCHAR(200)     NULL,
    parou_amamentar        BIT               NULL,
    idade_desmame          NVARCHAR(40)      NULL,
    motivo_desmame         NVARCHAR(200)     NULL,
    -- 3. Sinais de alerta -> tabela consulta_sinal_alerta (+ "Outros" aqui)
    outros_sinais          NVARCHAR(300)     NULL,
    -- 5. Desenvolvimento e laços de afeto
    desenvolvimento_afeto  NVARCHAR(500)     NULL,
    conduta                NVARCHAR(500)     NULL,
    registrado_em          DATETIME2(0)      NOT NULL CONSTRAINT df_consulta_registro DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_consulta               PRIMARY KEY (consulta_id),
    CONSTRAINT fk_consulta_crianca       FOREIGN KEY (crianca_id)       REFERENCES cadastro.crianca (crianca_id),
    CONSTRAINT fk_consulta_profissional  FOREIGN KEY (profissional_id)  REFERENCES cadastro.profissional (profissional_id),
    CONSTRAINT fk_consulta_especialidade FOREIGN KEY (especialidade_id) REFERENCES dominio.especialidade (especialidade_id),
    CONSTRAINT fk_consulta_unidade       FOREIGN KEY (unidade_id)       REFERENCES cadastro.unidade_saude (unidade_id),
    CONSTRAINT fk_consulta_agendamento   FOREIGN KEY (agendamento_id)   REFERENCES atendimento.agendamento (agendamento_id),
    CONSTRAINT ck_consulta_tipo          CHECK (tipo_atendimento IN ('PRIMEIRA_SEMANA','PUERICULTURA','TRIAGEM','VACINA','VISITA_DOMICILIAR')),
    CONSTRAINT ck_consulta_local         CHECK (local_atendimento IN ('UNIDADE','DOMICILIO')),
    CONSTRAINT ck_consulta_peso          CHECK (peso_g IS NULL OR peso_g BETWEEN 300 AND 30000),
    CONSTRAINT ck_consulta_comprimento   CHECK (comprimento_cm IS NULL OR comprimento_cm BETWEEN 25 AND 130),
    CONSTRAINT ck_consulta_pc            CHECK (perimetro_cefalico_cm IS NULL OR perimetro_cefalico_cm BETWEEN 20 AND 60),
    CONSTRAINT ck_consulta_aleitamento   CHECK (aleitamento IS NULL OR aleitamento IN ('LME','LM_LA','LA')),
    CONSTRAINT ck_consulta_dificuldade   CHECK (ISNULL(dificuldade_amamentar,0) = 0 OR dificuldade_descricao IS NOT NULL),
    -- Regra: a 1ª semana exige as 3 medidas marcadas com * no formulário (PC, peso, comprimento)
    CONSTRAINT ck_consulta_medidas_1sem  CHECK (tipo_atendimento <> 'PRIMEIRA_SEMANA'
                                             OR (peso_g IS NOT NULL AND comprimento_cm IS NOT NULL AND perimetro_cefalico_cm IS NOT NULL))
);
GO
CREATE UNIQUE INDEX uq_consulta_agendamento ON atendimento.consulta (agendamento_id) WHERE agendamento_id IS NOT NULL;
GO

/* Sinais de alerta: cada pergunta Sim/Não do formulário = 1 linha */
CREATE TABLE atendimento.consulta_sinal_alerta (
    consulta_id      INT NOT NULL,
    sinal_alerta_id  INT NOT NULL,
    presente         BIT NOT NULL,
    CONSTRAINT pk_consulta_sinal_alerta PRIMARY KEY (consulta_id, sinal_alerta_id),
    CONSTRAINT fk_consinal_consulta     FOREIGN KEY (consulta_id)     REFERENCES atendimento.consulta (consulta_id) ON DELETE CASCADE,
    CONSTRAINT fk_consinal_sinal        FOREIGN KEY (sinal_alerta_id) REFERENCES dominio.sinal_alerta (sinal_alerta_id)
);
GO

/* Vacinas aplicadas na criança (Hepatite B, BCG...) */
CREATE TABLE atendimento.vacina_aplicada (
    vacina_aplicada_id  INT IDENTITY(1,1) NOT NULL,
    crianca_id          INT               NOT NULL,
    vacina_id           INT               NOT NULL,
    dose                VARCHAR(4)        NOT NULL,
    data_aplicacao      DATE              NOT NULL,
    lote                VARCHAR(20)       NULL,
    profissional_id     INT               NULL,
    unidade_id          INT               NOT NULL,
    consulta_id         INT               NULL,
    registrado_em       DATETIME2(0)      NOT NULL CONSTRAINT df_vacina_aplicada_registro DEFAULT (SYSDATETIME()),
    CONSTRAINT pk_vacina_aplicada          PRIMARY KEY (vacina_aplicada_id),
    CONSTRAINT uq_vacina_aplicada_dose     UNIQUE (crianca_id, vacina_id, dose),
    CONSTRAINT fk_vacapl_crianca           FOREIGN KEY (crianca_id)      REFERENCES cadastro.crianca (crianca_id) ON DELETE CASCADE,
    CONSTRAINT fk_vacapl_vacina            FOREIGN KEY (vacina_id)       REFERENCES dominio.vacina (vacina_id),
    CONSTRAINT fk_vacapl_profissional      FOREIGN KEY (profissional_id) REFERENCES cadastro.profissional (profissional_id),
    CONSTRAINT fk_vacapl_unidade           FOREIGN KEY (unidade_id)      REFERENCES cadastro.unidade_saude (unidade_id),
    CONSTRAINT fk_vacapl_consulta          FOREIGN KEY (consulta_id)     REFERENCES atendimento.consulta (consulta_id),
    CONSTRAINT ck_vacapl_dose              CHECK (dose IN ('DU','D1','D2','D3','REF'))
);
GO
PRINT 'Tabelas de atendimento criadas.';
GO
