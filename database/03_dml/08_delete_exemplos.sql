/* =====================================================================
   08_delete_exemplos.sql  —  DML: expurgo controlado (DELETE)
   ---------------------------------------------------------------------
   Na saúde quase nada é apagado de verdade: o padrão do sistema é a
   EXCLUSÃO LÓGICA (criança.ativo = 0, agendamento.status = CANCELADO).
   A exclusão FÍSICA (DELETE) fica para: cadastro duplicado, registro de
   teste e dados fora do prazo de guarda. Sempre com WHERE bem restrito.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* 1) DELETE simples: telefone de recado que a mãe pediu para remover */
DELETE FROM cadastro.gestante_telefone
 WHERE gestante_id = 3
   AND tipo = 'RECADO';
GO

/* 2) Expurgo do agendamento de TESTE criado no script 07
      (só apaga se estiver cancelado e sem consulta ligada) */
DELETE a
FROM atendimento.agendamento a
WHERE a.observacao = N'Teste de procedure (script 07)'
  AND a.status = 'CANCELADO'
  AND NOT EXISTS (SELECT 1 FROM atendimento.consulta co WHERE co.agendamento_id = a.agendamento_id);
GO

/* 3) Cadastro DUPLICADO: a recepção cadastrou a Aurora duas vezes.
      Inserimos o duplicado e depois o apagamos. O prontuário aberto pelo
      trigger some junto por causa do ON DELETE CASCADE. */
DECLARE @duplicada INT, @prontuarios INT;

INSERT INTO cadastro.crianca (gestacao_id, nome, sexo, data_nascimento, unidade_referencia_id)
SELECT gestacao_id, nome, sexo, data_nascimento, unidade_referencia_id
FROM cadastro.crianca
WHERE crianca_id = 13;

SET @duplicada = SCOPE_IDENTITY();
SELECT @prontuarios = COUNT(*) FROM clinico.prontuario WHERE crianca_id = @duplicada;
PRINT CONCAT('Cadastro duplicado criado: ', @duplicada, ' | prontuários dele: ', @prontuarios);

BEGIN TRANSACTION;
    DELETE FROM cadastro.crianca WHERE crianca_id = @duplicada;

    IF @@ROWCOUNT = 1
        COMMIT TRANSACTION;
    ELSE
        ROLLBACK TRANSACTION;

-- (PRINT não aceita subconsulta: guardamos o COUNT numa variável antes)
SELECT @prontuarios = COUNT(*) FROM clinico.prontuario WHERE crianca_id = @duplicada;
PRINT CONCAT('Prontuários restantes do duplicado (esperado 0): ', @prontuarios);
GO

/* 4) Política de retenção: logs de auditoria com mais de 5 anos */
DELETE FROM auditoria.log_auditoria
 WHERE data_hora < DATEADD(YEAR, -5, SYSDATETIME());
PRINT CONCAT('Logs expurgados por retenção: ', @@ROWCOUNT);
GO

/* 5) Integridade referencial em ação (rode manualmente para mostrar o ERRO):
      não é possível apagar uma especialidade que tem consultas ligadas.

   DELETE FROM dominio.especialidade WHERE nome = N'Pediatria';
   -> Msg 547: The DELETE statement conflicted with the REFERENCE constraint ...
*/
PRINT 'Exemplos de DELETE executados.';
GO
