/* =====================================================================
   00_drop_database.sql  —  RESET TOTAL (use com cuidado!)
   ---------------------------------------------------------------------
   Apaga o banco CadernetaDigital inteiro. Só rode quando quiser
   recomeçar do zero (ex.: antes de uma demonstração).
   Não faz parte da execução normal (o runner pula a pasta 00_reset,
   a não ser que você rode "npm run db:reset").
   ===================================================================== */
USE master;
GO

IF DB_ID(N'CadernetaDigital') IS NOT NULL
BEGIN
    -- Derruba conexões abertas (DBeaver, aplicação) antes de apagar
    ALTER DATABASE CadernetaDigital SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CadernetaDigital;
    PRINT 'Banco CadernetaDigital removido.';
END
ELSE
    PRINT 'Banco CadernetaDigital não existe. Nada a fazer.';
GO
