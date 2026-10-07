class EscalaDiaModel {
  final int? id;
  final DateTime data;
  final int diaMes;
  final String diaSemana;
  final int semanaDoMes;
  final bool isFimDeSemana;
  final bool isFeriado;
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

  EscalaDiaModel({
    this.id,
    required this.data,
    required this.diaMes,
    required this.diaSemana,
    this.semanaDoMes = 1,
    this.isFimDeSemana = false,
    this.isFeriado = false,
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

  EscalaMensalModel({
    this.id,
    required this.ano,
    required this.mes,
    required this.titulo,
    this.observacoes,
    required this.dias,
    required this.estatisticas,
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
    );
  }
}
