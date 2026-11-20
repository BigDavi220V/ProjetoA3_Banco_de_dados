# Guia de entrega e ensaio

## O que apresentar

1. Leia o [contexto e as regras](05-requisitos-e-regras-de-negocio.md) e apresente o problema da caderneta em papel e os perfis de acesso.
2. Mostre o [DER](02-der.md), a [normalização](03-normalizacao-3fn.md) e o [dicionário](04-dicionario-de-dados.md). Explique gestação, criança, prontuário e seus relacionamentos.
3. Apresente a organização do banco e a arquitetura da aplicação em [01](01-arquitetura-do-banco.md) e [07](07-arquitetura-da-aplicacao.md). Os scripts estão em `database/`, separados por finalidade.
4. Demonstre os fluxos disponíveis seguindo o [roteiro](08-roteiro-da-apresentacao.md), somente depois de ensaiá-los em banco descartável. Tenha as imagens de `docs/img/` como apoio caso a demonstração falhe.
5. Entregue também o [relatório técnico em PDF](Relatorio_Tecnico_A3_CadernetaDigital.pdf). Ele é um artefato anterior às alterações posteriores; confira se reflete os critérios e a versão final solicitados pelo professor.

## Estado da verificação

Em 20/11/2026, `npm run check` carregou 28 rotas e `node --test` passou nos três testes existentes. A imagem da aplicação instalou as dependências com `npm ci`; o banco de demonstração em container foi criado e a API respondeu ao teste de saúde dentro do container. Em uma execução local anterior, página inicial e login de demonstração responderam. Esses testes não cobrem todos os perfis, operações CRUD, regras clínicas ou a interface completa.

A publicação da interface na porta 3003 não funcionou na rede interna Docker usada na máquina de teste. Por isso a execução em containers foi interrompida e não deve ser considerada pronta para apresentação no navegador. A opção de VM e DBeaver está descrita no [guia de ambiente](06-guia-vm-sqlserver-dbeaver.md), mas precisa ser montada e ensaiada. Containers compartilham o kernel do computador e não garantem isolamento completo; não monte pastas pessoais e não use dados reais.

## Antes da entrega

- Confirme com o professor o edital, formato, prazo e critérios: o edital original não está neste repositório.
- Revise e integre o PR aprovado à branch de entrega; confirme que o professor terá acesso ao repositório correto.
- Prepare uma VM isolada e uma base fictícia descartável; confira a conexão, a porta e `/api/health`.
- Ensaie login, busca, cadastro, atualização, agendamento, exclusão e relatórios com os perfis apropriados. Registre erros e corrija-os antes da demonstração.
- Confira no DBeaver as consultas, constraints, procedures e triggers que serão apresentados.
- Confira o PDF, DER e demais artefatos contra o edital; atualize o PDF se necessário.
- Preserve os dados: `db:setup` e `db:reset` recriam tabelas. Nunca os execute em banco que contenha dados a preservar.
- Não compartilhe arquivos `.env`, senhas reais ou dados pessoais. As credenciais de exemplo servem apenas à demonstração.
