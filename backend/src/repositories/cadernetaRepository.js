/**
 * repositories/cadernetaRepository.js — Prontuário / Caderneta da Criança
 *
 * Recursos de SQL usados aqui (bons para explicar na banca):
 *   - vários SELECTs num só comando (carregar)
 *   - MERGE  = "UPSERT": atualiza se existe, insere se não existe
 *   - OPENJSON = transforma a lista enviada pela tela (JSON) em linhas
 *   - OUTPUT ... INTO @tabela = captura o ID gerado num MERGE/INSERT
 *     (tabelas com trigger exigem o INTO)
 */
const { queryMultiplo, query } = require('../config/db');

/* ------------------------------------------------------------------ */
/* LEITURA: tudo da caderneta em uma ida ao banco                       */
/* ------------------------------------------------------------------ */
async function carregar(criancaId) {
  const rs = await queryMultiplo(`
    DECLARE @g INT = (SELECT gestacao_id FROM cadastro.crianca WHERE crianca_id = @id);

    /* 0 resumo */
    SELECT * FROM cadastro.vw_crianca_resumo WHERE crianca_id = @id;

    /* 1 gestação + dados da mãe */
    SELECT g.*, ge.nome AS mae_nome, ge.cpf AS mae_cpf, ge.cns AS mae_cns,
           ge.data_nascimento AS mae_data_nascimento,
           ge.tipo_sanguineo AS mae_tipo_sanguineo, ge.fator_rh AS mae_fator_rh,
           CONCAT(ge.logradouro, ', ', ge.numero, ' - ', ge.bairro) AS mae_endereco
    FROM clinico.gestacao g
    JOIN cadastro.gestante ge ON ge.gestante_id = g.gestante_id
    WHERE g.gestacao_id = @g;

    /* 2 sorologias */
    SELECT s.agravo_id, s.trimestre, s.resultado
    FROM clinico.sorologia_prenatal s WHERE s.gestacao_id = @g;

    /* 3 vacinas do pré-natal (LEFT JOIN: mostra também as não informadas) */
    SELECT v.vacina_id, v.nome, vp.recebeu
    FROM dominio.vacina v
    LEFT JOIN clinico.vacina_prenatal vp ON vp.vacina_id = v.vacina_id AND vp.gestacao_id = @g
    WHERE v.publico_alvo IN ('GESTANTE','AMBOS')
    ORDER BY v.vacina_id;

    /* 4 parto */
    SELECT pa.*, u.nome AS unidade_nome
    FROM clinico.parto pa LEFT JOIN cadastro.unidade_saude u ON u.unidade_id = pa.unidade_id
    WHERE pa.gestacao_id = @g;

    /* 5 nascimento */
    SELECT n.*, pr.nome AS assistido_por_nome
    FROM clinico.nascimento n
    LEFT JOIN cadastro.profissional pr ON pr.profissional_id = n.assistido_por_id
    WHERE n.crianca_id = @id;

    /* 6 internação */
    SELECT * FROM clinico.internacao_neonatal WHERE crianca_id = @id;

    /* 7 setores da internação */
    SELECT s.setor_id, st.sigla, st.nome, s.dias
    FROM clinico.internacao_setor s
    JOIN clinico.internacao_neonatal i ON i.internacao_id = s.internacao_id
    JOIN dominio.setor_internacao st   ON st.setor_id     = s.setor_id
    WHERE i.crianca_id = @id;

    /* 8 alta */
    SELECT * FROM clinico.alta_maternidade WHERE crianca_id = @id;

    /* 9 triagens (view calcula situação e resultado) */
    SELECT t.*, tt.nome AS tipo_nome, tt.orientacao_prazo, tt.avalia_lateralidade, p.nome AS profissional_nome
    FROM clinico.vw_triagem_situacao t
    JOIN dominio.tipo_triagem tt ON tt.tipo_triagem_id = t.tipo_triagem_id
    LEFT JOIN clinico.triagem_neonatal tn ON tn.triagem_id = t.triagem_id
    LEFT JOIN cadastro.profissional p     ON p.profissional_id = tn.profissional_id
    WHERE t.crianca_id = @id
    ORDER BY t.tipo_triagem_id;

    /* 10 resultado por lado */
    SELECT l.triagem_id, l.lado, l.resultado
    FROM clinico.triagem_resultado_lado l
    JOIN clinico.triagem_neonatal t ON t.triagem_id = l.triagem_id
    WHERE t.crianca_id = @id;

    /* 11 oximetria */
    SELECT o.triagem_id, o.numero_afericao, o.spo2_mao_direita, o.spo2_pe, o.aferido_em
    FROM clinico.oximetria_afericao o
    JOIN clinico.triagem_neonatal t ON t.triagem_id = o.triagem_id
    WHERE t.crianca_id = @id
    ORDER BY o.numero_afericao;

    /* 12 consultas (sinais presentes concatenados com STRING_AGG) */
    SELECT co.*, p.nome AS profissional_nome, e.nome AS especialidade_nome,
           (SELECT STRING_AGG(sa.nome, N', ')
              FROM atendimento.consulta_sinal_alerta cs
              JOIN dominio.sinal_alerta sa ON sa.sinal_alerta_id = cs.sinal_alerta_id
             WHERE cs.consulta_id = co.consulta_id AND cs.presente = 1) AS sinais_presentes
    FROM atendimento.consulta co
    JOIN cadastro.profissional p ON p.profissional_id = co.profissional_id
    JOIN dominio.especialidade e ON e.especialidade_id = co.especialidade_id
    WHERE co.crianca_id = @id
    ORDER BY co.data_consulta DESC;

    /* 13 vacinas aplicadas */
    SELECT va.vacina_aplicada_id, va.vacina_id, v.nome AS vacina, va.dose, va.data_aplicacao, va.lote,
           p.nome AS profissional_nome, u.nome AS unidade_nome
    FROM atendimento.vacina_aplicada va
    JOIN dominio.vacina v            ON v.vacina_id = va.vacina_id
    JOIN cadastro.unidade_saude u    ON u.unidade_id = va.unidade_id
    LEFT JOIN cadastro.profissional p ON p.profissional_id = va.profissional_id
    WHERE va.crianca_id = @id
    ORDER BY va.data_aplicacao;

    /* 14 linha do tempo */
    SELECT data_evento, tipo_evento, titulo, detalhe, profissional_nome
    FROM clinico.vw_linha_tempo_crianca
    WHERE crianca_id = @id
    ORDER BY data_evento DESC;

    /* 15 agendamentos */
    SELECT agendamento_id, data_hora, tipo_atendimento, local_atendimento, status,
           motivo_cancelamento, profissional_nome, especialidade_nome, unidade_nome, consulta_id
    FROM atendimento.vw_agenda_detalhada
    WHERE crianca_id = @id
    ORDER BY data_hora DESC;

    /* 16 telefones da mãe */
    SELECT t.ddd, t.numero, t.tipo, t.whatsapp
    FROM cadastro.gestante_telefone t
    JOIN clinico.gestacao g ON g.gestante_id = t.gestante_id
    WHERE g.gestacao_id = @g;`, { id: criancaId });

  const [resumo] = rs[0];
  if (!resumo) return null;

  const lados = rs[10];
  const oximetria = rs[11];
  const triagens = rs[9].map(t => ({
    ...t,
    lados: lados.filter(l => l.triagem_id === t.triagem_id),
    oximetria: oximetria.filter(o => o.triagem_id === t.triagem_id),
  }));

  return {
    resumo,
    gestacao:   { ...(rs[1][0] || {}), sorologias: rs[2], vacinas: rs[3], telefones: rs[16] },
    parto:      rs[4][0] || null,
    nascimento: rs[5][0] || null,
    internacao: rs[6][0] ? { ...rs[6][0], setores: rs[7] } : null,
    alta:       rs[8][0] || null,
    triagens,
    consultas:  rs[12],
    vacinas:    rs[13],
    linhaTempo: rs[14],
    agendamentos: rs[15],
  };
}

/* ------------------------------------------------------------------ */
/* PRÉ-NATAL (gestação + grade de sorologias + vacinas)                 */
/* ------------------------------------------------------------------ */
async function salvarPrenatal(gestacaoId, d, tx) {
  await query(`
    UPDATE clinico.gestacao
       SET planejada        = @planejada,
           fez_prenatal     = @fez_prenatal,
           numero_consultas = @numero_consultas,
           trimestre_inicio = @trimestre_inicio,
           tipo_gravidez    = @tipo_gravidez,
           gravidez_risco   = @gravidez_risco,
           risco_descricao  = @risco_descricao,
           dum              = @dum,
           observacao       = @observacao
     WHERE gestacao_id = @g;

    -- Grade de sorologias: apaga e regrava a partir do JSON da tela
    DELETE FROM clinico.sorologia_prenatal WHERE gestacao_id = @g;

    INSERT INTO clinico.sorologia_prenatal (gestacao_id, agravo_id, trimestre, resultado)
    SELECT @g, j.agravo_id, j.trimestre, j.resultado
    FROM OPENJSON(@sorologias)
         WITH (agravo_id INT '$.agravo_id', trimestre TINYINT '$.trimestre', resultado VARCHAR(3) '$.resultado') j
    WHERE j.resultado IS NOT NULL;

    -- Vacinas da gestante: MERGE (upsert) linha a linha
    MERGE clinico.vacina_prenatal AS alvo
    USING (SELECT j.vacina_id, j.recebeu
           FROM OPENJSON(@vacinas) WITH (vacina_id INT '$.vacina_id', recebeu BIT '$.recebeu') j
           WHERE j.recebeu IS NOT NULL) AS origem
       ON alvo.gestacao_id = @g AND alvo.vacina_id = origem.vacina_id
    WHEN MATCHED THEN UPDATE SET alvo.recebeu = origem.recebeu
    WHEN NOT MATCHED BY TARGET THEN INSERT (gestacao_id, vacina_id, recebeu) VALUES (@g, origem.vacina_id, origem.recebeu);`,
  {
    g: gestacaoId,
    planejada: d.planejada, fez_prenatal: d.fez_prenatal,
    numero_consultas: d.fez_prenatal === false ? null : d.numero_consultas,
    trimestre_inicio: d.fez_prenatal === false ? null : d.trimestre_inicio,
    tipo_gravidez: d.tipo_gravidez, gravidez_risco: d.gravidez_risco,
    risco_descricao: d.gravidez_risco ? d.risco_descricao : null,
    dum: d.dum, observacao: d.observacao,
    sorologias: JSON.stringify(d.sorologias || []),
    vacinas: JSON.stringify(d.vacinas || []),
  }, tx);
}

/* ------------------------------------------------------------------ */
/* PARTO + NASCIMENTO (+ tipagem sanguínea da mãe e do bebê)            */
/* ------------------------------------------------------------------ */
async function salvarNascimento(criancaId, gestacaoId, d, profissionalId, tx) {
  await query(`
    MERGE clinico.parto AS alvo
    USING (SELECT @g AS gestacao_id) AS origem ON alvo.gestacao_id = origem.gestacao_id
    WHEN MATCHED THEN UPDATE SET
         data_parto = @data_parto, local_tipo = @local_tipo, unidade_id = @unidade_id,
         local_descricao = @local_descricao, tipo_parto = @tipo_parto, motivo_cesarea = @motivo_cesarea,
         teve_acompanhante = @teve_acompanhante, acompanhante_descricao = @acompanhante_descricao
    WHEN NOT MATCHED THEN INSERT
         (gestacao_id, data_parto, local_tipo, unidade_id, local_descricao, tipo_parto,
          motivo_cesarea, teve_acompanhante, acompanhante_descricao)
         VALUES (@g, @data_parto, @local_tipo, @unidade_id, @local_descricao, @tipo_parto,
                 @motivo_cesarea, @teve_acompanhante, @acompanhante_descricao);

    MERGE clinico.nascimento AS alvo
    USING (SELECT @crianca_id AS crianca_id) AS origem ON alvo.crianca_id = origem.crianca_id
    WHEN MATCHED THEN UPDATE SET
         hora_nascimento = @hora_nascimento, contato_pele_a_pele = @contato_pele_a_pele,
         mamou_primeira_hora = @mamou_primeira_hora, apgar_1min = @apgar_1min, apgar_5min = @apgar_5min,
         clampeamento_oportuno = @clampeamento_oportuno, ig_semanas = @ig_semanas, ig_dias = @ig_dias,
         ig_metodo = @ig_metodo, ig_metodo_descricao = @ig_metodo_descricao, peso_g = @peso_g,
         comprimento_cm = @comprimento_cm, perimetro_cefalico_cm = @perimetro_cefalico_cm,
         reanimacao = @reanimacao, assistido_por_id = @assistido_por_id, coombs_direto = @coombs_direto,
         profilaxia_oftalmica = @profilaxia_oftalmica, vitamina_k = @vitamina_k,
         registrado_por_id = @registrado_por_id, registrado_em = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT
         (crianca_id, hora_nascimento, contato_pele_a_pele, mamou_primeira_hora, apgar_1min, apgar_5min,
          clampeamento_oportuno, ig_semanas, ig_dias, ig_metodo, ig_metodo_descricao, peso_g, comprimento_cm,
          perimetro_cefalico_cm, reanimacao, assistido_por_id, coombs_direto, profilaxia_oftalmica,
          vitamina_k, registrado_por_id)
         VALUES (@crianca_id, @hora_nascimento, @contato_pele_a_pele, @mamou_primeira_hora, @apgar_1min, @apgar_5min,
          @clampeamento_oportuno, @ig_semanas, @ig_dias, @ig_metodo, @ig_metodo_descricao, @peso_g, @comprimento_cm,
          @perimetro_cefalico_cm, @reanimacao, @assistido_por_id, @coombs_direto, @profilaxia_oftalmica,
          @vitamina_k, @registrado_por_id);

    -- Dados que pertencem a OUTRAS entidades (3FN): cada um na sua tabela
    UPDATE cadastro.crianca SET tipo_sanguineo = @bebe_tipo, fator_rh = @bebe_rh WHERE crianca_id = @crianca_id;
    UPDATE clinico.gestacao SET coombs_indireto = @coombs_indireto WHERE gestacao_id = @g;
    UPDATE ge SET ge.tipo_sanguineo = @mae_tipo, ge.fator_rh = @mae_rh
    FROM cadastro.gestante ge JOIN clinico.gestacao g ON g.gestante_id = ge.gestante_id
    WHERE g.gestacao_id = @g;`,
  {
    g: gestacaoId, crianca_id: criancaId,
    data_parto: d.data_parto, local_tipo: d.local_tipo, unidade_id: d.unidade_id,
    local_descricao: d.local_descricao, tipo_parto: d.tipo_parto,
    motivo_cesarea: d.tipo_parto === 'CESAREA' ? d.motivo_cesarea : null,
    teve_acompanhante: d.teve_acompanhante, acompanhante_descricao: d.teve_acompanhante ? d.acompanhante_descricao : null,
    hora_nascimento: d.hora_nascimento, contato_pele_a_pele: d.contato_pele_a_pele,
    mamou_primeira_hora: d.mamou_primeira_hora, apgar_1min: d.apgar_1min, apgar_5min: d.apgar_5min,
    clampeamento_oportuno: d.clampeamento_oportuno, ig_semanas: d.ig_semanas, ig_dias: d.ig_dias,
    ig_metodo: d.ig_metodo, ig_metodo_descricao: d.ig_metodo === 'OUTRO' ? d.ig_metodo_descricao : null,
    peso_g: d.peso_g, comprimento_cm: d.comprimento_cm, perimetro_cefalico_cm: d.perimetro_cefalico_cm,
    reanimacao: d.reanimacao, assistido_por_id: d.assistido_por_id, coombs_direto: d.coombs_direto,
    profilaxia_oftalmica: d.profilaxia_oftalmica, vitamina_k: d.vitamina_k,
    registrado_por_id: profissionalId,
    bebe_tipo: d.bebe_tipo_sanguineo, bebe_rh: d.bebe_fator_rh,
    mae_tipo: d.mae_tipo_sanguineo, mae_rh: d.mae_fator_rh,
    coombs_indireto: d.coombs_indireto,
  }, tx);
}

/* ------------------------------------------------------------------ */
/* INTERNAÇÃO NEONATAL + ALTA                                           */
/* ------------------------------------------------------------------ */
async function salvarAlta(criancaId, d, profissionalId, tx) {
  if (d.internado) {
    await query(`
      DECLARE @int TABLE (internacao_id INT);

      MERGE clinico.internacao_neonatal AS alvo
      USING (SELECT @crianca_id AS crianca_id) AS origem ON alvo.crianca_id = origem.crianca_id
      WHEN MATCHED THEN UPDATE SET motivo = @motivo, data_inicio = @data_inicio
      WHEN NOT MATCHED THEN INSERT (crianca_id, motivo, data_inicio) VALUES (@crianca_id, @motivo, @data_inicio)
      OUTPUT INSERTED.internacao_id INTO @int;

      DELETE s FROM clinico.internacao_setor s JOIN @int i ON i.internacao_id = s.internacao_id;

      INSERT INTO clinico.internacao_setor (internacao_id, setor_id, dias)
      SELECT i.internacao_id, j.setor_id, j.dias
      FROM @int i
      CROSS JOIN OPENJSON(@setores) WITH (setor_id INT '$.setor_id', dias SMALLINT '$.dias') j
      WHERE j.dias > 0;`,
    { crianca_id: criancaId, motivo: d.motivo_internacao, data_inicio: d.data_inicio_internacao,
      setores: JSON.stringify(d.setores || []) }, tx);
  } else {
    // "Internação: Não" -> remove (setores vão junto pelo ON DELETE CASCADE)
    await query(`DELETE FROM clinico.internacao_neonatal WHERE crianca_id = @crianca_id;`, { crianca_id: criancaId }, tx);
  }

  if (d.data_alta) {
    await query(`
      MERGE clinico.alta_maternidade AS alvo
      USING (SELECT @crianca_id AS crianca_id) AS origem ON alvo.crianca_id = origem.crianca_id
      WHEN MATCHED THEN UPDATE SET data_alta = @data_alta, peso_alta_g = @peso_alta_g,
           comprimento_alta_cm = @comprimento_alta_cm, aleitamento = @aleitamento,
           resumo_alta = @resumo_alta, registrado_por_id = @registrado_por_id
      WHEN NOT MATCHED THEN INSERT (crianca_id, data_alta, peso_alta_g, comprimento_alta_cm, aleitamento, resumo_alta, registrado_por_id)
           VALUES (@crianca_id, @data_alta, @peso_alta_g, @comprimento_alta_cm, @aleitamento, @resumo_alta, @registrado_por_id);`,
    {
      crianca_id: criancaId, data_alta: d.data_alta, peso_alta_g: d.peso_alta_g,
      comprimento_alta_cm: d.comprimento_alta_cm, aleitamento: d.aleitamento,
      resumo_alta: d.resumo_alta, registrado_por_id: profissionalId,
    }, tx);
  }
}

/* ------------------------------------------------------------------ */
/* TRIAGEM NEONATAL (um teste por vez)                                  */
/* ------------------------------------------------------------------ */
async function salvarTriagem(criancaId, codigo, d, profissionalId, tx) {
  const [linha] = await query(`
    DECLARE @tipo INT = (SELECT tipo_triagem_id FROM dominio.tipo_triagem WHERE codigo = @codigo);
    DECLARE @t TABLE (triagem_id INT);

    IF @tipo IS NULL
        THROW 50060, N'Tipo de triagem desconhecido.', 1;

    MERGE clinico.triagem_neonatal AS alvo
    USING (SELECT @crianca_id AS crianca_id, @tipo AS tipo_triagem_id) AS origem
       ON alvo.crianca_id = origem.crianca_id AND alvo.tipo_triagem_id = origem.tipo_triagem_id
    WHEN MATCHED THEN UPDATE SET realizada = @realizada, data_realizacao = @data_realizacao,
         metodo = @metodo, data_reteste = @data_reteste, conduta = @conduta,
         profissional_id = @profissional_id, registrado_em = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT (crianca_id, tipo_triagem_id, realizada, data_realizacao, metodo, data_reteste, conduta, profissional_id)
         VALUES (@crianca_id, @tipo, @realizada, @data_realizacao, @metodo, @data_reteste, @conduta, @profissional_id)
    OUTPUT INSERTED.triagem_id INTO @t;

    -- resultados por lado (olhinho/orelhinha)
    DELETE l FROM clinico.triagem_resultado_lado l JOIN @t t ON t.triagem_id = l.triagem_id;
    INSERT INTO clinico.triagem_resultado_lado (triagem_id, lado, resultado)
    SELECT t.triagem_id, j.lado, j.resultado
    FROM @t t CROSS JOIN OPENJSON(@lados) WITH (lado CHAR(1) '$.lado', resultado VARCHAR(8) '$.resultado') j
    WHERE @realizada = 1 AND j.resultado IS NOT NULL;

    -- aferições de saturação (coraçãozinho)
    DELETE o FROM clinico.oximetria_afericao o JOIN @t t ON t.triagem_id = o.triagem_id;
    INSERT INTO clinico.oximetria_afericao (triagem_id, numero_afericao, spo2_mao_direita, spo2_pe, aferido_em)
    SELECT t.triagem_id, j.numero_afericao, j.spo2_mao_direita, j.spo2_pe, SYSDATETIME()
    FROM @t t CROSS JOIN OPENJSON(@oximetria)
         WITH (numero_afericao TINYINT '$.numero_afericao', spo2_mao_direita TINYINT '$.spo2_mao_direita', spo2_pe TINYINT '$.spo2_pe') j
    WHERE @realizada = 1 AND j.spo2_mao_direita IS NOT NULL AND j.spo2_pe IS NOT NULL;

    SELECT t.triagem_id, clinico.fn_resultado_triagem(t.triagem_id) AS resultado FROM @t t;`,
  {
    codigo, crianca_id: criancaId,
    realizada: !!d.realizada,
    data_realizacao: d.realizada ? d.data_realizacao : null,
    metodo: d.realizada ? d.metodo : null,
    data_reteste: d.realizada ? d.data_reteste : null,
    conduta: d.conduta, profissional_id: profissionalId,
    lados: JSON.stringify(d.lados || []),
    oximetria: JSON.stringify(d.oximetria || []),
  }, tx);
  return linha;
}

module.exports = { carregar, salvarPrenatal, salvarNascimento, salvarAlta, salvarTriagem };
