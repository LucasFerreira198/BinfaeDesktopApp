class PendenciaModel {
  final int id;
  final String titulo;
  final String? descricao;
  final String tipo; // GERAL, MANUTENCAO, META, INVENTARIO
  final String prioridade; // BAIXA, MEDIA, ALTA, URGENTE
  final String status; // PENDENTE, EM_ANDAMENTO, CONCLUIDA, BAIXADA, CANCELADA
  final DateTime? prazoLimite;
  final int? itemId;
  final String? itemNome;
  final String? itemBmp;
  final int? militarResponsavelId;
  final String? militarResponsavelNome;
  final String? resolucao;
  final String? laudoTecnico;
  final DateTime? criadoEm;
  final DateTime? concluidoEm;
  final String? criadoPorNome;
  final String? concluidoPorNome;

  PendenciaModel({
    required this.id,
    required this.titulo,
    this.descricao,
    this.tipo = 'GERAL',
    this.prioridade = 'MEDIA',
    this.status = 'PENDENTE',
    this.prazoLimite,
    this.itemId,
    this.itemNome,
    this.itemBmp,
    this.militarResponsavelId,
    this.militarResponsavelNome,
    this.resolucao,
    this.laudoTecnico,
    this.criadoEm,
    this.concluidoEm,
    this.criadoPorNome,
    this.concluidoPorNome,
  });

  bool get isConcluida => status == 'CONCLUIDA' || status == 'BAIXADA' || status == 'CANCELADA';
  bool get isManutencao => tipo == 'MANUTENCAO';

  factory PendenciaModel.fromJson(Map<String, dynamic> json) {
    return PendenciaModel(
      id: json['id'] as int? ?? 0,
      titulo: json['titulo'] as String? ?? '',
      descricao: json['descricao'] as String?,
      tipo: json['tipo'] as String? ?? 'GERAL',
      prioridade: json['prioridade'] as String? ?? 'MEDIA',
      status: json['status'] as String? ?? 'PENDENTE',
      prazoLimite: json['prazo_limite'] != null ? DateTime.tryParse(json['prazo_limite']) : null,
      itemId: json['item_id'] as int?,
      itemNome: json['item_nome'] as String?,
      itemBmp: json['item_bmp'] as String?,
      militarResponsavelId: json['militar_responsavel_id'] as int?,
      militarResponsavelNome: json['militar_responsavel_nome'] as String?,
      resolucao: json['resolucao'] as String?,
      laudoTecnico: json['laudo_tecnico'] as String?,
      criadoEm: json['criado_em'] != null ? DateTime.tryParse(json['criado_em']) : null,
      concluidoEm: json['concluido_em'] != null ? DateTime.tryParse(json['concluido_em']) : null,
      criadoPorNome: json['criado_por_nome'] as String?,
      concluidoPorNome: json['concluido_por_nome'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'descricao': descricao,
    'tipo': tipo,
    'prioridade': prioridade,
    'status': status,
    'prazo_limite': prazoLimite?.toIso8601String(),
    'item_id': itemId,
    'militar_responsavel_id': militarResponsavelId,
    'resolucao': resolucao,
    'laudo_tecnico': laudoTecnico,
  };
}
