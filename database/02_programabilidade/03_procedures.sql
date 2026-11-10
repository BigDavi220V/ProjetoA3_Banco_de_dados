/* =====================================================================
   03_procedures.sql  —  Stored procedures (operações com regras)
   ---------------------------------------------------------------------
   Usamos procedure quando a operação tem VÁRIOS passos que precisam
   acontecer juntos (transação) ou regras que dependem de outras tabelas.
   Erros de regra de negócio usam THROW com códigos 50000+; a API
   devolve a mensagem para a tela.

     50010..50019  agenda
     50020..50029  consulta
     50030..50039  cadastro
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* ---------------------------------------------------------------------
   AGENDAR CONSULTA
   Regras: data futura; criança ativa; profissional ativo e habilitado na
   especialidade; sem sobreposição de horário do profissional; consulta
   da 1ª semana só até o 7º dia de vida e uma única vez.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE atendimento.sp_agendar_consulta
    @crianca_id        INT,
    @profissional_id   INT,
    @especialidade_id  INT,
    @unidade_id        INT,
    @data_hora         DATETIME2(0),
    @tipo_atendimento  VARCHAR(20),
    @local_atendimento VARCHAR(10)   = 'UNIDADE',
    @duracao_min       SMALLINT      = 30,
    @observacao        NVARCHAR(200) = NULL,
    @usuario_id        INT           = NULL,
    @agendamento_id    INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- qualquer erro desfaz a transação inteira

    DECLARE @nascimento DATE;

    IF @data_hora < SYSDATETIME()
        THROW 50010, N'Não é possível agendar em data/hora que já passou.', 1;

    SELECT @nascimento = data_nascimento
    FROM cadastro.crianca
    WHERE crianca_id = @crianca_id AND ativo = 1;

    IF @nascimento IS NULL
        THROW 50011, N'Criança não encontrada ou com cadastro inativo.', 1;

    IF NOT EXISTS (SELECT 1
                   FROM cadastro.profissional_especialidade pe
                   JOIN cadastro.profissional p ON p.profissional_id = pe.profissional_id
                   WHERE pe.profissional_id = @profissional_id
                     AND pe.especialidade_id = @especialidade_id
                     AND p.ativo = 1)
        THROW 50012, N'O profissional escolhido não atende nesta especialidade (ou está inativo).', 1;

    IF @tipo_atendimento = 'PRIMEIRA_SEMANA'
    BEGIN
        IF DATEDIFF(DAY, @nascimento, CAST(@data_hora AS DATE)) > 7
            THROW 50014, N'A consulta da 1ª semana precisa acontecer até o 7º dia de vida (ideal: do 3º ao 5º dia).', 1;

        IF EXISTS (SELECT 1 FROM atendimento.agendamento
                   WHERE crianca_id = @crianca_id
                     AND tipo_atendimento = 'PRIMEIRA_SEMANA'
                     AND status IN ('AGENDADO','REALIZADO'))
            THROW 50015, N'Esta criança já tem consulta da 1ª semana agendada ou realizada.', 1;
    END;

    BEGIN TRANSACTION;

        -- UPDLOCK + HOLDLOCK: trava a faixa de horários do profissional até o COMMIT,
        -- impedindo que duas recepcionistas marquem o mesmo horário ao mesmo tempo.
        IF EXISTS (SELECT 1
                   FROM atendimento.agendamento WITH (UPDLOCK, HOLDLOCK)
                   WHERE profissional_id = @profissional_id
                     AND status = 'AGENDADO'
                     AND data_hora < DATEADD(MINUTE, @duracao_min, @data_hora)
                     AND DATEADD(MINUTE, duracao_min, data_hora) > @data_hora)
            -- Com XACT_ABORT ON, o THROW já desfaz a transação inteira
            -- (inclusive a transação aberta pela API que chamou a procedure).
            THROW 50013, N'O profissional já tem um atendimento nesse horário.', 1;

        INSERT INTO atendimento.agendamento
            (crianca_id, profissional_id, especialidade_id, unidade_id, data_hora,
             duracao_min, tipo_atendimento, local_atendimento, observacao, criado_por_usuario_id)
        VALUES
            (@crianca_id, @profissional_id, @especialidade_id, @unidade_id, @data_hora,
             @duracao_min, @tipo_atendimento, @local_atendimento, @observacao, @usuario_id);

        SET @agendamento_id = SCOPE_IDENTITY();

    COMMIT TRANSACTION;
END;
GO

/* ---------------------------------------------------------------------
   CANCELAR (ou marcar FALTOU) — exclusão LÓGICA do agendamento
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE atendimento.sp_cancelar_agendamento
    @agendamento_id INT,
    @motivo         NVARCHAR(200),
    @novo_status    VARCHAR(10) = 'CANCELADO'
AS
BEGIN
    SET NOCOUNT ON;

    IF @novo_status NOT IN ('CANCELADO','FALTOU')
        THROW 50016, N'Status inválido para cancelamento.', 1;

    IF NULLIF(LTRIM(RTRIM(@motivo)), N'') IS NULL AND @novo_status = 'CANCELADO'
        THROW 50017, N'Informe o motivo do cancelamento.', 1;

    UPDATE atendimento.agendamento
       SET status              = @novo_status,
           motivo_cancelamento = @motivo
     WHERE agendamento_id = @agendamento_id
       AND status = 'AGENDADO';

    IF @@ROWCOUNT = 0
        THROW 50018, N'Agendamento não encontrado ou não está mais em aberto.', 1;
END;
GO

/* ---------------------------------------------------------------------
   REGISTRAR CONSULTA (ex.: Consulta da 1ª Semana)
   Grava a consulta + os sinais de alerta numa única transação.
   @sinais_json = '[{"sinal_alerta_id":1,"presente":false}, ...]'
   OPENJSON transforma o JSON em linhas para o INSERT ... SELECT.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE atendimento.sp_registrar_consulta
    @crianca_id             INT,
    @profissional_id        INT,
    @especialidade_id       INT,
    @unidade_id             INT,
    @tipo_atendimento       VARCHAR(20),
    @local_atendimento      VARCHAR(10)   = 'UNIDADE',
    @data_consulta          DATETIME2(0)  = NULL,
    @agendamento_id         INT           = NULL,
    @peso_g                 SMALLINT      = NULL,
    @comprimento_cm         DECIMAL(4,1)  = NULL,
    @perimetro_cefalico_cm  DECIMAL(4,1)  = NULL,
    @aleitamento            VARCHAR(5)    = NULL,
    @aleitamento_observacao NVARCHAR(200) = NULL,
    @dificuldade_amamentar  BIT           = NULL,
    @dificuldade_descricao  NVARCHAR(200) = NULL,
    @parou_amamentar        BIT           = NULL,
    @idade_desmame          NVARCHAR(40)  = NULL,
    @motivo_desmame         NVARCHAR(200) = NULL,
    @outros_sinais          NVARCHAR(300) = NULL,
    @desenvolvimento_afeto  NVARCHAR(500) = NULL,
    @conduta                NVARCHAR(500) = NULL,
    @sinais_json            NVARCHAR(MAX) = NULL,
    @consulta_id            INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM cadastro.crianca WHERE crianca_id = @crianca_id AND ativo = 1)
        THROW 50020, N'Criança não encontrada ou com cadastro inativo.', 1;

    IF @agendamento_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM atendimento.agendamento
                       WHERE agendamento_id = @agendamento_id
                         AND crianca_id = @crianca_id
                         AND status = 'AGENDADO')
        THROW 50021, N'O agendamento informado não está em aberto para esta criança.', 1;

    IF @sinais_json IS NOT NULL AND ISJSON(@sinais_json) = 0
        THROW 50022, N'Lista de sinais de alerta em formato inválido.', 1;

    BEGIN TRANSACTION;

        INSERT INTO atendimento.consulta
            (crianca_id, profissional_id, especialidade_id, unidade_id, agendamento_id,
             tipo_atendimento, local_atendimento, data_consulta,
             peso_g, comprimento_cm, perimetro_cefalico_cm,
             aleitamento, aleitamento_observacao, dificuldade_amamentar, dificuldade_descricao,
             parou_amamentar, idade_desmame, motivo_desmame,
             outros_sinais, desenvolvimento_afeto, conduta)
        VALUES
            (@crianca_id, @profissional_id, @especialidade_id, @unidade_id, @agendamento_id,
             @tipo_atendimento, @local_atendimento, ISNULL(@data_consulta, SYSDATETIME()),
             @peso_g, @comprimento_cm, @perimetro_cefalico_cm,
             @aleitamento, @aleitamento_observacao, @dificuldade_amamentar, @dificuldade_descricao,
             @parou_amamentar, @idade_desmame, @motivo_desmame,
             @outros_sinais, @desenvolvimento_afeto, @conduta);

        SET @consulta_id = SCOPE_IDENTITY();

        IF @sinais_json IS NOT NULL
            INSERT INTO atendimento.consulta_sinal_alerta (consulta_id, sinal_alerta_id, presente)
            SELECT @consulta_id, j.sinal_alerta_id, j.presente
            FROM OPENJSON(@sinais_json)
                 WITH (sinal_alerta_id INT '$.sinal_alerta_id',
                       presente        BIT '$.presente') AS j;

        -- (o trigger trg_consulta_conclui_agendamento marca o agendamento como REALIZADO)

    COMMIT TRANSACTION;
END;
GO

/* ---------------------------------------------------------------------
   INATIVAR CRIANÇA (exclusão lógica) + cancelar agendamentos futuros
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE cadastro.sp_inativar_crianca
    @crianca_id INT,
    @motivo     NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NULLIF(LTRIM(RTRIM(@motivo)), N'') IS NULL
        THROW 50030, N'Informe o motivo da inativação.', 1;

    BEGIN TRANSACTION;

        UPDATE cadastro.crianca
           SET ativo = 0, inativado_em = SYSDATETIME(), motivo_inativacao = @motivo
         WHERE crianca_id = @crianca_id AND ativo = 1;

        IF @@ROWCOUNT = 0
            THROW 50031, N'Criança não encontrada ou já inativa.', 1;   -- XACT_ABORT desfaz a transação

        UPDATE atendimento.agendamento
           SET status = 'CANCELADO',
               motivo_cancelamento = LEFT(CONCAT(N'Cadastro inativado: ', @motivo), 200)
         WHERE crianca_id = @crianca_id
           AND status = 'AGENDADO'
           AND data_hora >= SYSDATETIME();

    COMMIT TRANSACTION;
END;
GO

/* ---------------------------------------------------------------------
   RELATÓRIO: volume de atendimentos por especialidade num intervalo
   (pedido explícito do edital). LEFT JOIN para mostrar também as
   especialidades com zero atendimentos no período.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE relatorio.sp_atendimentos_por_especialidade
    @inicio DATE,
    @fim    DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @fim < @inicio
        THROW 50040, N'A data final deve ser maior ou igual à inicial.', 1;

    SELECT
        e.nome                                      AS especialidade,
        COUNT(co.consulta_id)                       AS total_consultas,
        COUNT(DISTINCT co.crianca_id)               AS criancas_atendidas,
        CAST(AVG(CAST(co.peso_g AS DECIMAL(7,1))) AS DECIMAL(7,1)) AS peso_medio_g
    FROM dominio.especialidade e
    LEFT JOIN atendimento.consulta co
           ON co.especialidade_id = e.especialidade_id
          AND co.data_consulta >= @inicio
          AND co.data_consulta <  DATEADD(DAY, 1, @fim)   -- inclui o dia final inteiro
    GROUP BY e.nome
    ORDER BY total_consultas DESC, e.nome;
END;
GO
PRINT 'Procedures criadas.';
GO
