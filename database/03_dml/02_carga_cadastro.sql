/* =====================================================================
   02_carga_cadastro.sql  —  DML: unidades, profissionais, gestantes
   ---------------------------------------------------------------------
   Massa de teste FICTÍCIA (nomes, CPFs e CNS inventados).
   IDENTITY_INSERT ON permite informar o ID manualmente — assim os
   scripts seguintes podem referenciar "gestante 4", "criança 8" etc.
   As datas são RELATIVAS a hoje (@hoje), para a demonstração sempre
   mostrar recém-nascidos "da semana", em qualquer dia em que rodar.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

SET IDENTITY_INSERT cadastro.unidade_saude ON;
INSERT INTO cadastro.unidade_saude (unidade_id, cnes, nome, tipo, logradouro, numero, bairro, municipio, uf, telefone) VALUES
 (1, '2402001', N'USF Pirajá',                          'USF',                 N'Rua Direta de Pirajá',        N'120',  N'Pirajá',        N'Salvador', 'BA', '7133011001'),
 (2, '2402002', N'UBS Liberdade',                       'UBS',                 N'Estrada da Liberdade',        N'455',  N'Liberdade',     N'Salvador', 'BA', '7133011002'),
 (3, '2402003', N'Maternidade Municipal Nova Esperança','MATERNIDADE',         N'Av. San Martin',              N'1800', N'São Caetano',   N'Salvador', 'BA', '7133011003'),
 (4, '2402004', N'Centro de Parto Normal Mãe Baiana',   'CENTRO_PARTO_NORMAL', N'Rua do Cabula',               N'77',   N'Cabula',        N'Salvador', 'BA', '7133011004'),
 (5, '2402005', N'Hospital Municipal da Criança',       'HOSPITAL',            N'Av. Vasco da Gama',           N'3000', N'Rio Vermelho',  N'Salvador', 'BA', '7133011005');
SET IDENTITY_INSERT cadastro.unidade_saude OFF;
GO

SET IDENTITY_INSERT cadastro.profissional ON;
INSERT INTO cadastro.profissional (profissional_id, nome, cpf, categoria_id, registro_conselho, uf_conselho, unidade_id, email) VALUES
 ( 1, N'Ana Paula Ribeiro',       '10000000101', 1, '23451',  'BA', 1, 'ana.ribeiro@saude.exemplo'),
 ( 2, N'Carlos Eduardo Menezes',  '10000000202', 1, '18822',  'BA', 3, 'carlos.menezes@saude.exemplo'),
 ( 3, N'Juliana Costa Prado',     '10000000303', 1, '20117',  'BA', 3, 'juliana.prado@saude.exemplo'),
 ( 4, N'Roberto Sales Andrade',   '10000000404', 1, '15540',  'BA', 5, 'roberto.andrade@saude.exemplo'),
 ( 5, N'Marina Lopes Teixeira',   '10000000505', 2, '412233', 'BA', 1, 'marina.teixeira@saude.exemplo'),
 ( 6, N'Patrícia Gomes Silva',    '10000000606', 2, '398120', 'BA', 3, 'patricia.silva@saude.exemplo'),
 ( 7, N'Fernanda Rocha Lima',     '10000000707', 2, '455901', 'BA', 2, 'fernanda.lima@saude.exemplo'),
 ( 8, N'Luana Pereira Santos',    '10000000808', 3, '801122', 'BA', 1, 'luana.santos@saude.exemplo'),
 ( 9, N'Jorge Almeida Reis',      '10000000909', 3, '802211', 'BA', 3, 'jorge.reis@saude.exemplo'),
 (10, N'Camila Duarte Freitas',   '10000001010', 4, '7788',   'BA', 3, 'camila.freitas@saude.exemplo'),
 (11, N'Marcos Vinícius Lima',    '10000001111', 1, '26701',  'BA', 2, 'marcos.lima@saude.exemplo'),
 (12, N'Rita de Cássia Moura',    '10000001212', 5, NULL,     NULL, 1, 'rita.moura@saude.exemplo');
SET IDENTITY_INSERT cadastro.profissional OFF;
GO

-- N:N profissional x especialidade
INSERT INTO cadastro.profissional_especialidade (profissional_id, especialidade_id, data_titulo) VALUES
 ( 1, 1, '2014-02-10'), ( 1, 8, '2016-03-01'),
 ( 2, 2, '2011-07-20'), ( 2, 1, '2009-02-15'),
 ( 3, 3, '2012-01-30'),
 ( 4, 6, '2010-05-05'),
 ( 5, 5, '2018-06-11'), ( 5, 8, '2017-01-09'),
 ( 6, 4, '2015-08-22'),
 ( 7, 5, '2019-09-30'),
 ( 8, 8, NULL),
 ( 9, 5, NULL),
 (10, 7, '2016-04-18'),
 (11, 1, '2020-02-01'), (11, 8, '2021-03-15');
GO

DECLARE @hoje DATE = CAST(GETDATE() AS DATE);

SET IDENTITY_INSERT cadastro.gestante ON;
INSERT INTO cadastro.gestante
    (gestante_id, nome, cpf, cns, data_nascimento, tipo_sanguineo, fator_rh,
     logradouro, numero, bairro, cep, unidade_referencia_id)
VALUES
 ( 1, N'Joana Santos Oliveira',     '20000000101', '700000000000101', DATEADD(DAY, -(28*365+40),  @hoje), 'A',  '+', N'Rua São Bartolomeu',      N'15',  N'Pirajá',     '40335000', 1),
 ( 2, N'Beatriz Souza Lima',        '20000000202', NULL,              DATEADD(DAY, -(31*365+12),  @hoje), 'O',  '+', N'Travessa Boa Vista',      N'8',   N'Pirajá',     '40335010', 1),
 ( 3, N'Carla Conceição Pereira',   '20000000303', '700000000000303', DATEADD(DAY, -(24*365+200), @hoje), 'B',  '+', N'Rua Lima e Silva',        N'230', N'Liberdade',  '40325000', 2),
 ( 4, N'Vitória Bispo Nascimento',  NULL,          '700000000000404', DATEADD(DAY, -(17*365+90),  @hoje), 'O',  '-', N'Rua do Queimadinho',      N'41',  N'Pirajá',     '40335020', 1),
 ( 5, N'Daniela Ferreira Santana',  '20000000505', '700000000000505', DATEADD(DAY, -(35*365+5),   @hoje), 'AB', '+', N'Rua Pero Vaz',            N'1002',N'Liberdade',  '40325010', 2),
 ( 6, N'Renata Rocha Barbosa',      '20000000606', NULL,              DATEADD(DAY, -(29*365+150), @hoje), 'A',  '-', N'Rua Nova de Pirajá',      N'66',  N'Pirajá',     '40335030', 1),
 ( 7, N'Tatiane Almeida Cruz',      '20000000707', '700000000000707', DATEADD(DAY, -(26*365+33),  @hoje), 'O',  '+', N'Rua Campinas',            N'19',  N'Pirajá',     '40335040', 1),
 ( 8, N'Priscila Araújo Matos',     '20000000808', '700000000000808', DATEADD(DAY, -(38*365+77),  @hoje), 'B',  '-', N'Ladeira do Curuzu',       N'200', N'Liberdade',  '40325020', 2),
 ( 9, N'Luciana Teixeira Moura',    '20000000909', NULL,              DATEADD(DAY, -(22*365+260), @hoje), 'O',  '+', N'Rua Senta Pua',           N'5',   N'Liberdade',  '40325030', 2),
 (10, N'Fabiana Lopes Silva',       '20000001010', '700000000001010', DATEADD(DAY, -(30*365+101), @hoje), 'A',  '+', N'Rua Aliança',             N'300', N'Pirajá',     '40335050', 1),
 (11, N'Simone Nunes Carvalho',     '20000001111', '700000000001111', DATEADD(DAY, -(33*365+18),  @hoje), 'O',  '-', N'Rua Japão',               N'12',  N'Liberdade',  '40325040', 2),
 (12, N'Kelly Menezes Dias',        '20000001212', NULL,              DATEADD(DAY, -(27*365+222), @hoje), 'A',  '+', N'Rua Direta do Lobato',    N'91',  N'Pirajá',     '40335060', 1);
SET IDENTITY_INSERT cadastro.gestante OFF;
GO

-- Atributo multivalorado: algumas mães têm mais de um telefone
INSERT INTO cadastro.gestante_telefone (gestante_id, ddd, numero, tipo, whatsapp) VALUES
 ( 1, '71', '988110101', 'CELULAR', 1), ( 1, '71', '33221010',  'FIXO',    0),
 ( 2, '71', '988110202', 'CELULAR', 1),
 ( 3, '71', '988110303', 'CELULAR', 1), ( 3, '71', '999330303', 'RECADO',  0),
 ( 4, '71', '988110404', 'CELULAR', 1), ( 4, '71', '999440404', 'RECADO',  1),
 ( 5, '71', '988110505', 'CELULAR', 1),
 ( 6, '71', '988110606', 'CELULAR', 0),
 ( 7, '71', '988110707', 'CELULAR', 1),
 ( 8, '71', '988110808', 'CELULAR', 1), ( 8, '71', '33228080',  'FIXO',    0),
 ( 9, '71', '988110909', 'CELULAR', 1),
 (10, '71', '988111010', 'CELULAR', 1), (10, '71', '999101010', 'RECADO',  1),
 (11, '71', '988111111', 'CELULAR', 1),
 (12, '71', '988111212', 'CELULAR', 0);
GO
PRINT 'Cadastro base carregado.';
GO
