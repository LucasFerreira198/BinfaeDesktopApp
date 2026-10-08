class RelatorioDiarioModel {
  final int id;
  final DateTime dataReferencia;
  final DateTime periodoInicio;
  final DateTime periodoFim;
  int? militarServicoId;
  String? militarServicoNome;
  String? militarServicoPosto;
  String? militarServicoGuerra;
  final Map<String, dynamic> dadosAutomaticos;
  String? ocorrenciasMilitar;
  String status; // RASCUNHO, LANCADO
  final DateTime? lancadoEm;
  final String? lancadoPorNome;
  final List<String> emailsDisparados;
  final String? whatsappStatus;

  RelatorioDiarioModel({
    required this.id,
    required this.dataReferencia,
    required this.periodoInicio,
    required this.periodoFim,
    this.militarServicoId,
    this.militarServicoNome,
    this.militarServicoPosto,
    this.militarServicoGuerra,
    required this.dadosAutomaticos,
    this.ocorrenciasMilitar,
    this.status = 'RASCUNHO',
    this.lancadoEm,
    this.lancadoPorNome,
    this.emailsDisparados = const [],
    this.whatsappStatus,
  });

  bool get isLancado => status == 'LANCADO';

  List<dynamic> get itensManutencao =>
      dadosAutomaticos['itens_manutencao'] as List<dynamic>? ?? [];

  List<dynamic> get itensConsertados =>
      dadosAutomaticos['itens_consertados'] as List<dynamic>? ?? [];

  List<dynamic> get itensBaixados =>
      dadosAutomaticos['itens_baixados'] as List<dynamic>? ?? [];

  List<dynamic> get missoesCautelas =>
      dadosAutomaticos['missoes_cautelas'] as List<dynamic>? ?? [];

  List<dynamic> get cautelasPeriodo =>
      dadosAutomaticos['cautelas_periodo'] as List<dynamic>? ?? [];

  List<dynamic> get devolucoesPeriodo =>
      dadosAutomaticos['devolucoes_periodo'] as List<dynamic>? ?? [];

  List<dynamic> get pendenciasCriadas =>
      dadosAutomaticos['pendencias_criadas'] as List<dynamic>? ?? [];

  List<dynamic> get pendenciasResolvidas =>
      dadosAutomaticos['pendencias_resolvidas'] as List<dynamic>? ?? [];

  factory RelatorioDiarioModel.fromJson(Map<String, dynamic> json) {
    return RelatorioDiarioModel(
      id: json['id'] as int? ?? 0,
      dataReferencia: DateTime.parse(json['data_referencia']),
      periodoInicio: DateTime.parse(json['periodo_inicio']),
      periodoFim: DateTime.parse(json['periodo_fim']),
      militarServicoId: json['militar_servico_id'] as int?,
      militarServicoNome: json['militar_servico_nome'] as String?,
      militarServicoPosto: json['militar_servico_posto'] as String?,
      militarServicoGuerra: json['militar_servico_guerra'] as String?,
      dadosAutomaticos: json['dados_automaticos'] as Map<String, dynamic>? ?? {},
      ocorrenciasMilitar: json['ocorrencias_militar'] as String?,
      status: json['status'] as String? ?? 'RASCUNHO',
      lancadoEm: json['lancado_em'] != null ? DateTime.tryParse(json['lancado_em']) : null,
      lancadoPorNome: json['lancado_por_nome'] as String?,
      emailsDisparados: (json['emails_disparados'] as List?)?.map((e) => e.toString()).toList() ?? [],
      whatsappStatus: json['whatsapp_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'data_referencia': dataReferencia.toIso8601String(),
    'periodo_inicio': periodoInicio.toIso8601String(),
    'periodo_fim': periodoFim.toIso8601String(),
    'militar_servico_id': militarServicoId,
    'militar_servico_nome': militarServicoNome,
    'militar_servico_posto': militarServicoPosto,
    'militar_servico_guerra': militarServicoGuerra,
    'dados_automaticos': dadosAutomaticos,
    'ocorrencias_militar': ocorrenciasMilitar,
    'status': status,
    'lancado_em': lancadoEm?.toIso8601String(),
    'lancado_por_nome': lancadoPorNome,
    'emails_disparados': emailsDisparados,
    'whatsapp_status': whatsappStatus,
  };
}
