/* =====================================================================
   04_triggers.sql  —  Triggers (reações automáticas do banco)
   ---------------------------------------------------------------------
   Trigger roda SOZINHO quando acontece INSERT/UPDATE/DELETE na tabela.
   Dentro dele existem duas tabelas temporárias especiais:
     inserted -> como as linhas ficaram (INSERT/UPDATE)
     deleted  -> como as linhas eram    (UPDATE/DELETE)
   Todos foram escritos para funcionar com VÁRIAS linhas de uma vez.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* 1) Toda criança cadastrada ganha um prontuário automaticamente */
CREATE OR ALTER TRIGGER cadastro.trg_crianca_abrir_prontuario
ON cadastro.crianca
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO clinico.prontuario (crianca_id, unidade_id)
    SELECT i.crianca_id, i.unidade_referencia_id
    FROM inserted i
    WHERE NOT EXISTS (SELECT 1 FROM clinico.prontuario p WHERE p.crianca_id = i.crianca_id);
END;
GO

/* 2) Registrou a consulta de um agendamento? O agendamento vira REALIZADO */
CREATE OR ALTER TRIGGER atendimento.trg_consulta_conclui_agendamento
ON atendimento.consulta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE a
       SET a.status = 'REALIZADO'
    FROM atendimento.agendamento a
    JOIN inserted i ON i.agendamento_id = a.agendamento_id
    WHERE a.status = 'AGENDADO';
END;
GO

/* 3) Regras de data que dependem de OUTRA tabela (CHECK não consegue):
      alta, triagem e vacina não podem ser antes do nascimento da criança */
CREATE OR ALTER TRIGGER clinico.trg_alta_valida_data
ON clinico.alta_maternidade
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN cadastro.crianca c ON c.crianca_id = i.crianca_id
               WHERE i.data_alta < c.data_nascimento)
        THROW 50050, N'A data da alta não pode ser anterior ao nascimento.', 1;
END;
GO

CREATE OR ALTER TRIGGER clinico.trg_triagem_valida_data
ON clinico.triagem_neonatal
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN cadastro.crianca c ON c.crianca_id = i.crianca_id
               WHERE i.data_realizacao < c.data_nascimento)
        THROW 50051, N'A data da triagem não pode ser anterior ao nascimento.', 1;
END;
GO

CREATE OR ALTER TRIGGER atendimento.trg_vacina_valida_data
ON atendimento.vacina_aplicada
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN cadastro.crianca c ON c.crianca_id = i.crianca_id
               WHERE i.data_aplicacao < c.data_nascimento
                  OR i.data_aplicacao > CAST(GETDATE() AS DATE))
        THROW 50052, N'Data de aplicação da vacina inválida (antes do nascimento ou no futuro).', 1;
END;
GO

/* 4) AUDITORIA: guarda "antes" e "depois" em JSON.
      O usuário logado vem do SESSION_CONTEXT, que a API preenche com
      EXEC sp_set_session_context 'usuario_id', <id> antes de gravar.
      FULL OUTER JOIN entre inserted e deleted descobre a operação:
        só inserted = I | só deleted = D | os dois = U                 */
CREATE OR ALTER TRIGGER cadastro.trg_auditoria_crianca
ON cadastro.crianca
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @usuario INT = TRY_CAST(SESSION_CONTEXT(N'usuario_id') AS INT);

    INSERT INTO auditoria.log_auditoria (tabela, operacao, chave, usuario_id, dados_antes, dados_depois)
    SELECT N'cadastro.crianca',
           CASE WHEN i.crianca_id IS NOT NULL AND d.crianca_id IS NOT NULL THEN 'U'
                WHEN i.crianca_id IS NOT NULL THEN 'I' ELSE 'D' END,
           CAST(COALESCE(i.crianca_id, d.crianca_id) AS NVARCHAR(50)),
           @usuario,
           (SELECT x.* FROM deleted  x WHERE x.crianca_id = d.crianca_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT x.* FROM inserted x WHERE x.crianca_id = i.crianca_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.crianca_id = i.crianca_id;
END;
GO

CREATE OR ALTER TRIGGER clinico.trg_auditoria_nascimento
ON clinico.nascimento
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @usuario INT = TRY_CAST(SESSION_CONTEXT(N'usuario_id') AS INT);

    INSERT INTO auditoria.log_auditoria (tabela, operacao, chave, usuario_id, dados_antes, dados_depois)
    SELECT N'clinico.nascimento',
           CASE WHEN i.nascimento_id IS NOT NULL AND d.nascimento_id IS NOT NULL THEN 'U'
                WHEN i.nascimento_id IS NOT NULL THEN 'I' ELSE 'D' END,
           CAST(COALESCE(i.nascimento_id, d.nascimento_id) AS NVARCHAR(50)),
           @usuario,
           (SELECT x.* FROM deleted  x WHERE x.nascimento_id = d.nascimento_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT x.* FROM inserted x WHERE x.nascimento_id = i.nascimento_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.nascimento_id = i.nascimento_id;
END;
GO

CREATE OR ALTER TRIGGER atendimento.trg_auditoria_agendamento
ON atendimento.agendamento
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @usuario INT = TRY_CAST(SESSION_CONTEXT(N'usuario_id') AS INT);

    INSERT INTO auditoria.log_auditoria (tabela, operacao, chave, usuario_id, dados_antes, dados_depois)
    SELECT N'atendimento.agendamento',
           CASE WHEN i.agendamento_id IS NOT NULL AND d.agendamento_id IS NOT NULL THEN 'U'
                WHEN i.agendamento_id IS NOT NULL THEN 'I' ELSE 'D' END,
           CAST(COALESCE(i.agendamento_id, d.agendamento_id) AS NVARCHAR(50)),
           @usuario,
           (SELECT x.* FROM deleted  x WHERE x.agendamento_id = d.agendamento_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT x.* FROM inserted x WHERE x.agendamento_id = i.agendamento_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.agendamento_id = i.agendamento_id;
END;
GO

CREATE OR ALTER TRIGGER atendimento.trg_auditoria_consulta
ON atendimento.consulta
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @usuario INT = TRY_CAST(SESSION_CONTEXT(N'usuario_id') AS INT);

    INSERT INTO auditoria.log_auditoria (tabela, operacao, chave, usuario_id, dados_antes, dados_depois)
    SELECT N'atendimento.consulta',
           CASE WHEN i.consulta_id IS NOT NULL AND d.consulta_id IS NOT NULL THEN 'U'
                WHEN i.consulta_id IS NOT NULL THEN 'I' ELSE 'D' END,
           CAST(COALESCE(i.consulta_id, d.consulta_id) AS NVARCHAR(50)),
           @usuario,
           (SELECT x.* FROM deleted  x WHERE x.consulta_id = d.consulta_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           (SELECT x.* FROM inserted x WHERE x.consulta_id = i.consulta_id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM inserted i
    FULL OUTER JOIN deleted d ON d.consulta_id = i.consulta_id;
END;
GO
PRINT 'Triggers criados.';
GO
