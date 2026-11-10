/* =====================================================================
   07_update_exemplos.sql  —  DML: exemplos de MODIFICAÇÃO (UPDATE)
   ---------------------------------------------------------------------
   Situações reais do dia a dia da caderneta digital.
   Rode bloco a bloco no DBeaver/SSMS para mostrar na apresentação.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

/* 1) UPDATE simples: correção de digitação no comprimento ao nascer */
UPDATE clinico.nascimento
   SET comprimento_cm = 48.0
 WHERE crianca_id = 6;
GO

/* 2) UPDATE com subconsulta: resultado do tipo sanguíneo do bebê 7 chegou */
UPDATE cadastro.crianca
   SET tipo_sanguineo = 'O',
       fator_rh       = '+'
 WHERE crianca_id = (SELECT c.crianca_id
                     FROM cadastro.crianca c
                     WHERE c.nome = N'Théo Almeida Cruz');
GO

/* 3) UPDATE com JOIN (sintaxe UPDATE ... FROM do SQL Server):
      a mãe 4 mudou de bairro e passou a ser acompanhada pela UBS Liberdade.
      A criança acompanha a unidade da mãe. */
UPDATE cadastro.gestante
   SET logradouro = N'Rua Lima e Silva', numero = N'88', bairro = N'Liberdade',
       cep = '40325050', unidade_referencia_id = 2
 WHERE gestante_id = 4;

UPDATE c
   SET c.unidade_referencia_id = ge.unidade_referencia_id
FROM cadastro.crianca  c
JOIN clinico.gestacao  g  ON g.gestacao_id  = c.gestacao_id
JOIN cadastro.gestante ge ON ge.gestante_id = g.gestante_id
WHERE ge.gestante_id = 4
  AND c.unidade_referencia_id <> ge.unidade_referencia_id;
GO

/* 4) Rotina diária: agendamentos de dias anteriores que continuaram
      "AGENDADO" e não têm consulta viram "FALTOU" (NOT EXISTS) */
UPDATE a
   SET a.status = 'FALTOU',
       a.motivo_cancelamento = N'Encerrado automaticamente: sem registro de atendimento'
FROM atendimento.agendamento a
WHERE a.status = 'AGENDADO'
  AND a.data_hora < CAST(GETDATE() AS DATE)
  AND NOT EXISTS (SELECT 1 FROM atendimento.consulta co WHERE co.agendamento_id = a.agendamento_id);
PRINT CONCAT('Agendamentos encerrados como FALTOU: ', @@ROWCOUNT);
GO

/* 5) UPDATE dentro de TRANSAÇÃO com conferência antes do COMMIT:
      duas mães confirmaram que o celular tem WhatsApp.
      Se mexer em mais linhas do que o esperado, desfaz tudo. */
BEGIN TRANSACTION;

    UPDATE cadastro.gestante_telefone
       SET whatsapp = 1
     WHERE gestante_id IN (6, 12)
       AND tipo = 'CELULAR';

    IF @@ROWCOUNT = 2
        COMMIT TRANSACTION;
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Quantidade inesperada de linhas: alteração desfeita.';
    END;
GO

/* 5b) Correção em lote: lote de vacina digitado errado (HB24A207 -> HB24A208) */
UPDATE atendimento.vacina_aplicada
   SET lote = 'HB24A208'
 WHERE lote = 'HB24A207'
   AND crianca_id IN (10, 11);
GO

/* 6) Usando as PROCEDURES (as mesmas que a aplicação chama):
      agenda uma puericultura e depois a cancela (exclusão lógica). */
DECLARE @novo_id INT,
        @data    DATETIME2(0) = DATEADD(HOUR, 16, CAST(DATEADD(DAY, 10, CAST(GETDATE() AS DATE)) AS DATETIME2(0)));

EXEC atendimento.sp_agendar_consulta
     @crianca_id = 6, @profissional_id = 1, @especialidade_id = 1, @unidade_id = 1,
     @data_hora = @data, @tipo_atendimento = 'PUERICULTURA',
     @observacao = N'Teste de procedure (script 07)',
     @agendamento_id = @novo_id OUTPUT;

PRINT CONCAT('Agendamento criado pela procedure: ', @novo_id);

EXEC atendimento.sp_cancelar_agendamento
     @agendamento_id = @novo_id,
     @motivo = N'Teste: cancelamento pela procedure';
GO
PRINT 'Exemplos de UPDATE executados.';
GO
