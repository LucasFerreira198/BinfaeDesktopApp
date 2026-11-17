class EscalaTrocaModel {
  final int id;
  final int escalaId;
  final int diaId;
  final DateTime dataEscala;
  final String tipoServico;
  final int militarSolicitanteId;
  final String? militarSolicitanteNome;
  final String? militarSolicitantePosto;
  final String? militarSolicitanteGuerra;
  final int? militarSolicitanteSaram;
  final int militarSubstitutoId;
  final String? militarSubstitutoNome;
  final String? militarSubstitutoPosto;
  final String? militarSubstitutoGuerra;
  final int? militarSubstitutoSaram;
  final String motivo;
  final String status;
  final String? homologadoPorNome;
  final DateTime? homologadoEm;
  final String? justificativaRecusa;
  final DateTime criadoEm;

  EscalaTrocaModel({
    required this.id,
    required this.escalaId,
    required this.diaId,
    required this.dataEscala,
    required this.tipoServico,
    required this.militarSolicitanteId,
    this.militarSolicitanteNome,
    this.militarSolicitantePosto,
    this.militarSolicitanteGuerra,
    this.militarSolicitanteSaram,
    required this.militarSubstitutoId,
    this.militarSubstitutoNome,
    this.militarSubstitutoPosto,
    this.militarSubstitutoGuerra,
    this.militarSubstitutoSaram,
    required this.motivo,
    required this.status,
    this.homologadoPorNome,
    this.homologadoEm,
    this.justificativaRecusa,
    required this.criadoEm,
  });

  factory EscalaTrocaModel.fromJson(Map<String, dynamic> json) {
    return EscalaTrocaModel(
      id: json['id'] as int? ?? 0,
      escalaId: json['escala_id'] as int? ?? 0,
      diaId: json['dia_id'] as int? ?? 0,
      dataEscala: DateTime.tryParse(json['data_escala']?.toString() ?? '') ?? DateTime.now(),
      tipoServico: json['tipo_servico'] as String? ?? 'SOBREAVISO',
      militarSolicitanteId: json['militar_solicitante_id'] as int? ?? 0,
      militarSolicitanteNome: json['militar_solicitante_nome'] as String?,
      militarSolicitantePosto: json['militar_solicitante_posto'] as String?,
      militarSolicitanteGuerra: json['militar_solicitante_guerra'] as String?,
      militarSolicitanteSaram: json['militar_solicitante_saram'] as int?,
      militarSubstitutoId: json['militar_substituto_id'] as int? ?? 0,
      militarSubstitutoNome: json['militar_substituto_nome'] as String?,
      militarSubstitutoPosto: json['militar_substituto_posto'] as String?,
      militarSubstitutoGuerra: json['militar_substituto_guerra'] as String?,
      militarSubstitutoSaram: json['militar_substituto_saram'] as int?,
      motivo: json['motivo'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDENTE',
      homologadoPorNome: json['homologado_por_nome'] as String?,
      homologadoEm: json['homologado_em'] != null ? DateTime.tryParse(json['homologado_em'].toString()) : null,
      justificativaRecusa: json['justificativa_recusa'] as String?,
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class EscalaDiaModel {
  final int? id;
  final DateTime data;
  final int diaMes;
  final String diaSemana;
  final int semanaDoMes;
  final bool isFimDeSemana;
  final bool isFeriado;
  final bool isFeriadoEspecial;
  final String? descricaoFeriado;
  int? militarSvId;
  String? militarSvNome;
  String? militarSvPosto;
  String? militarSvGuerra;
  int? militarExpd1Id;
  String? militarExpd1Nome;
  String? militarExpd1Posto;
  String? militarExpd1Guerra;
  int? militarExpd2Id;
  String? militarExpd2Nome;
  String? militarExpd2Posto;
  String? militarExpd2Guerra;
  bool trocaPendente;
  bool trocaHomologada;
  List<EscalaTrocaModel> trocas;

  EscalaDiaModel({
    this.id,
    required this.data,
    required this.diaMes,
    required this.diaSemana,
    this.semanaDoMes = 1,
    this.isFimDeSemana = false,
    this.isFeriado = false,
    this.isFeriadoEspecial = false,
    this.descricaoFeriado,
    this.militarSvId,
    this.militarSvNome,
    this.militarSvPosto,
    this.militarSvGuerra,
    this.militarExpd1Id,
    this.militarExpd1Nome,
    this.militarExpd1Posto,
    this.militarExpd1Guerra,
    this.militarExpd2Id,
    this.militarExpd2Nome,
    this.militarExpd2Posto,
    this.militarExpd2Guerra,
    this.trocaPendente = false,
    this.trocaHomologada = false,
    this.trocas = const [],
  });

  factory EscalaDiaModel.fromJson(Map<String, dynamic> json) {
    return EscalaDiaModel(
      id: json['id'] as int?,
      data: DateTime.parse(json['data']),
      diaMes: json['dia_mes'] as int? ?? 1,
      diaSemana: json['dia_semana'] as String? ?? '',
      semanaDoMes: json['semana_do_mes'] as int? ?? 1,
      isFimDeSemana: json['is_fim_de_semana'] as bool? ?? false,
      isFeriado: json['is_feriado'] as bool? ?? false,
      isFeriadoEspecial: json['is_feriado_especial'] as bool? ?? false,
      descricaoFeriado: json['descricao_feriado'] as String?,
      militarSvId: json['militar_sv_id'] as int?,
      militarSvNome: json['militar_sv_nome'] as String?,
      militarSvPosto: json['militar_sv_posto'] as String?,
      militarSvGuerra: json['militar_sv_guerra'] as String?,
      militarExpd1Id: json['militar_expd1_id'] as int?,
      militarExpd1Nome: json['militar_expd1_nome'] as String?,
      militarExpd1Posto: json['militar_expd1_posto'] as String?,
      militarExpd1Guerra: json['militar_expd1_guerra'] as String?,
      militarExpd2Id: json['militar_expd2_id'] as int?,
      militarExpd2Nome: json['militar_expd2_nome'] as String?,
      militarExpd2Posto: json['militar_expd2_posto'] as String?,
      militarExpd2Guerra: json['militar_expd2_guerra'] as String?,
      trocaPendente: json['troca_pendente'] as bool? ?? false,
      trocaHomologada: json['troca_homologada'] as bool? ?? false,
      trocas: (json['trocas'] as List?)
              ?.map((t) => EscalaTrocaModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'dia_mes': diaMes,
    'militar_sv_id': militarSvId,
    'militar_expd1_id': militarExpd1Id,
    'militar_expd2_id': militarExpd2Id,
    'is_feriado': isFeriado,
    'descricao_feriado': descricaoFeriado,
  };
}

class EstatisticaMilitarModel {
  final int militarId;
  final String nomeGuerra;
  final String postoGraduacao;
  final int saram;
  int totalSv;
  int totalExpd;
  int semana1;
  int semana2;
  int semana3;
  int semana4;
  int semana5;

  EstatisticaMilitarModel({
    required this.militarId,
    required this.nomeGuerra,
    required this.postoGraduacao,
    required this.saram,
    this.totalSv = 0,
    this.totalExpd = 0,
    this.semana1 = 0,
    this.semana2 = 0,
    this.semana3 = 0,
    this.semana4 = 0,
    this.semana5 = 0,
  });

  factory EstatisticaMilitarModel.fromJson(Map<String, dynamic> json) {
    return EstatisticaMilitarModel(
      militarId: json['militar_id'] as int? ?? 0,
      nomeGuerra: json['nome_guerra'] as String? ?? '',
      postoGraduacao: json['posto_graduacao'] as String? ?? '',
      saram: json['saram'] as int? ?? 0,
      totalSv: json['total_sv'] as int? ?? 0,
      totalExpd: json['total_expd'] as int? ?? 0,
      semana1: json['semana_1'] as int? ?? 0,
      semana2: json['semana_2'] as int? ?? 0,
      semana3: json['semana_3'] as int? ?? 0,
      semana4: json['semana_4'] as int? ?? 0,
      semana5: json['semana_5'] as int? ?? 0,
    );
  }
}

class EscalaMensalModel {
  final int? id;
  final int ano;
  final int mes;
  final String titulo;
  final String? observacoes;
  final List<EscalaDiaModel> dias;
  final List<EstatisticaMilitarModel> estatisticas;
  final int totalTrocasMes;
  final int totalTrocasPendentes;
  final List<EscalaTrocaModel> trocasPendentes;

  EscalaMensalModel({
    this.id,
    required this.ano,
    required this.mes,
    required this.titulo,
    this.observacoes,
    required this.dias,
    required this.estatisticas,
    this.totalTrocasMes = 0,
    this.totalTrocasPendentes = 0,
    this.trocasPendentes = const [],
  });

  factory EscalaMensalModel.fromJson(Map<String, dynamic> json) {
    return EscalaMensalModel(
      id: json['id'] as int?,
      ano: json['ano'] as int? ?? DateTime.now().year,
      mes: json['mes'] as int? ?? DateTime.now().month,
      titulo: json['titulo'] as String? ?? 'Escala de Sobreaviso',
      observacoes: json['observacoes'] as String?,
      dias: (json['dias'] as List?)
              ?.map((d) => EscalaDiaModel.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      estatisticas: (json['estatisticas'] as List?)
              ?.map((e) => EstatisticaMilitarModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalTrocasMes: json['total_trocas_mes'] as int? ?? 0,
      totalTrocasPendentes: json['total_trocas_pendentes'] as int? ?? 0,
      trocasPendentes: (json['trocas_pendentes'] as List?)
              ?.map((t) => EscalaTrocaModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
