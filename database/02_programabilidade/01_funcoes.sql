/* =====================================================================
   01_funcoes.sql  —  Funções (regras de cálculo dentro do banco)
   ---------------------------------------------------------------------
   Por que no banco? Porque são regras CLÍNICAS que precisam dar o mesmo
   resultado na tela, nos relatórios e no DBeaver. Escreveu uma vez,
   todo mundo usa igual.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* Idade em dias (no período neonatal a idade é contada em dias) */
CREATE OR ALTER FUNCTION clinico.fn_idade_em_dias
(
    @data_nascimento DATE,
    @referencia      DATE = NULL      -- NULL = hoje
)
RETURNS INT
AS
BEGIN
    RETURN DATEDIFF(DAY, @data_nascimento, ISNULL(@referencia, CAST(GETDATE() AS DATE)));
END;
GO

/* Adequação do peso para a idade gestacional:
   PIG  = abaixo do percentil 10  (pequeno para a IG)
   AIG  = entre p10 e p90         (adequado)
   GIG  = acima do percentil 90   (grande para a IG)
   Usa a tabela de referência dominio.referencia_peso_ig. */
CREATE OR ALTER FUNCTION clinico.fn_classificar_peso_ig
(
    @peso_g     SMALLINT,
    @ig_semanas TINYINT,
    @sexo       CHAR(1)
)
RETURNS VARCHAR(3)
AS
BEGIN
    DECLARE @p10 SMALLINT, @p90 SMALLINT;

    IF @peso_g IS NULL OR @ig_semanas IS NULL OR @sexo NOT IN ('M','F')
        RETURN NULL;

    SELECT @p10 = p10_g, @p90 = p90_g
    FROM dominio.referencia_peso_ig
    WHERE ig_semanas = @ig_semanas AND sexo = @sexo;

    IF @p10 IS NULL RETURN NULL;   -- semana fora da tabela

    RETURN CASE
               WHEN @peso_g < @p10 THEN 'PIG'
               WHEN @peso_g > @p90 THEN 'GIG'
               ELSE 'AIG'
           END;
END;
GO

/* Teste do coraçãozinho (regra do formulário):
   NORMAL   = saturação >= 95% nas duas medidas E diferença < 3%
   Se a 1ª aferição não for normal  -> 'REPETIR' (nova aferição após 1 hora)
   Se a 2ª aferição não for normal  -> 'ALTERADO' (encaminhar para ecocardiograma) */
CREATE OR ALTER FUNCTION clinico.fn_resultado_oximetria (@triagem_id INT)
RETURNS VARCHAR(8)
AS
BEGIN
    DECLARE @numero TINYINT, @mao INT, @pe INT;

    -- considera a aferição mais recente
    SELECT TOP (1)
           @numero = numero_afericao,
           @mao    = spo2_mao_direita,
           @pe     = spo2_pe
    FROM clinico.oximetria_afericao
    WHERE triagem_id = @triagem_id
    ORDER BY numero_afericao DESC;

    IF @numero IS NULL RETURN NULL;

    IF @mao >= 95 AND @pe >= 95 AND ABS(@mao - @pe) < 3
        RETURN 'NORMAL';

    RETURN CASE WHEN @numero = 1 THEN 'REPETIR' ELSE 'ALTERADO' END;
END;
GO

/* Resultado consolidado de qualquer triagem:
   - olhinho/orelhinha: ALTERADO se algum lado alterou
   - coraçãozinho: regra da oximetria
   - pezinho: o resultado vem do laboratório -> 'COLETADO' */
CREATE OR ALTER FUNCTION clinico.fn_resultado_triagem (@triagem_id INT)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @realizada BIT;
    SELECT @realizada = realizada FROM clinico.triagem_neonatal WHERE triagem_id = @triagem_id;

    IF @realizada IS NULL OR @realizada = 0 RETURN NULL;

    IF EXISTS (SELECT 1 FROM clinico.triagem_resultado_lado WHERE triagem_id = @triagem_id)
        RETURN CASE WHEN EXISTS (SELECT 1 FROM clinico.triagem_resultado_lado
                                 WHERE triagem_id = @triagem_id AND resultado = 'ALTERADO')
                    THEN 'ALTERADO' ELSE 'NORMAL' END;

    IF EXISTS (SELECT 1 FROM clinico.oximetria_afericao WHERE triagem_id = @triagem_id)
        RETURN clinico.fn_resultado_oximetria(@triagem_id);

    RETURN 'COLETADO';
END;
GO
PRINT 'Funções criadas.';
GO
