/* =====================================================================
   05_carga_usuarios.sql  —  DML: perfis e usuários de demonstração
   ---------------------------------------------------------------------
   Senha de TODOS os usuários de teste: caderneta123
   O valor gravado é o HASH bcrypt (gerado pelo Node com bcryptjs).
   O banco nunca vê a senha em texto puro.
   ===================================================================== */
USE CadernetaDigital;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- obrigatório para índices filtrados e JSON
GO

INSERT INTO seguranca.perfil (codigo, nome, descricao) VALUES
 ('RECEPCAO',   N'Recepção',          N'Cadastra crianças e gestantes, gerencia a agenda'),
 ('ENFERMAGEM', N'Enfermagem',        N'Registra triagens, consultas, vacinas e dados de nascimento/alta'),
 ('MEDICO',     N'Médico(a)',         N'Registra consultas e dados clínicos; consulta a agenda'),
 ('GESTOR',     N'Gestão da rede',    N'Relatórios, auditoria e exclusões físicas');
GO

DECLARE @hash CHAR(60) = '$2a$10$C5qOW56KBhrUlUrREFgaTum.h6KRHJSZ/JtVoib4bIciMYKiB/lTO';

INSERT INTO seguranca.usuario (login, senha_hash, perfil_id, profissional_id, nome_exibicao)
SELECT v.login, @hash, p.perfil_id, v.profissional_id, v.nome
FROM (VALUES
 ('recepcao@caderneta.local',   'RECEPCAO',   12,   N'Rita (Recepção)'),
 ('enfermeira@caderneta.local', 'ENFERMAGEM',  5,   N'Enf. Marina'),
 ('tecnica@caderneta.local',    'ENFERMAGEM',  8,   N'Téc. Luana'),
 ('medico@caderneta.local',     'MEDICO',      1,   N'Dra. Ana Paula'),
 ('gestor@caderneta.local',     'GESTOR',   NULL,   N'Coordenação da Rede')
) AS v (login, perfil, profissional_id, nome)
JOIN seguranca.perfil p ON p.codigo = v.perfil;
GO
PRINT 'Perfis e usuários carregados.';
GO
