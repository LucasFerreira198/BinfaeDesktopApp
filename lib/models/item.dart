class LocationModel {
  final int id;
  final String nome;
  final String? tipo;
  final String? descricao;
  final int? parentId;
  final String? caminhoCompleto;

  LocationModel({
    required this.id,
    required this.nome,
    this.tipo,
    this.descricao,
    this.parentId,
    this.caminhoCompleto,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? 'Sem nome',
      tipo: json['tipo'] as String?,
      descricao: json['descricao'] as String?,
      parentId: json['parent_id'] as int?,
      caminhoCompleto: json['caminho_completo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'tipo': tipo,
    'descricao': descricao,
    'parent_id': parentId,
    'caminho_completo': caminhoCompleto,
  };
}

class GroupModel {
  final int id;
  final String nome;
  final String? descricao;

  GroupModel({
    required this.id,
    required this.nome,
    this.descricao,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      descricao: json['descricao'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'descricao': descricao,
  };
}

class SubgroupModel {
  final int id;
  final String nome;
  final String? descricao;
  final int grupoId;
  final GroupModel? grupo;

  SubgroupModel({
    required this.id,
    required this.nome,
    this.descricao,
    required this.grupoId,
    this.grupo,
  });

  factory SubgroupModel.fromJson(Map<String, dynamic> json) {
    return SubgroupModel(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      descricao: json['descricao'] as String?,
      grupoId: json['grupo_id'] as int? ?? 0,
      grupo: json['grupo'] != null ? GroupModel.fromJson(json['grupo']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'descricao': descricao,
    'grupo_id': grupoId,
    'grupo': grupo?.toJson(),
  };
}

class ItemModel {
  final int id;
  final String nome;
  final String? bmp;
  final String? codigoInterno;
  final String? numeroSerie;
  final String tipoControle; // UNITARIO ou GRANEL
  final double quantidade;
  final double quantidadeMinima;
  final String unidadeMedida;
  final String estadoConservacao; // NOVO, BOM, REGULAR, COM_DEFEITO, SUCATA
  final String status; // DISPONIVEL, EM_USO, EM_MANUTENCAO, CAUTELADO, BAIXADO
  final String? observacoes;
  final Map<String, dynamic>? caracteristicas;
  final int? subgrupoId;
  final int? localId;
  final int? parentId;
  final LocationModel? local;
  final SubgroupModel? subgrupo;
  final List<ItemModel>? componentes;
  final String? criadoEm;
  final String? atualizadoEm;

  ItemModel({
    required this.id,
    required this.nome,
    this.bmp,
    this.codigoInterno,
    this.numeroSerie,
    this.tipoControle = 'UNITARIO',
    this.quantidade = 1.0,
    this.quantidadeMinima = 0.0,
    this.unidadeMedida = 'UNIDADE',
    this.estadoConservacao = 'BOM',
    this.status = 'DISPONIVEL',
    this.observacoes,
    this.caracteristicas,
    this.subgrupoId,
    this.localId,
    this.parentId,
    this.local,
    this.subgrupo,
    this.componentes,
    this.criadoEm,
    this.atualizadoEm,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? 'Sem nome',
      bmp: json['bmp'] as String?,
      codigoInterno: json['codigo_interno'] as String?,
      numeroSerie: json['numero_serie'] as String?,
      tipoControle: json['tipo_controle'] as String? ?? 'UNITARIO',
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 1.0,
      quantidadeMinima: (json['quantidade_minima'] as num?)?.toDouble() ?? 0.0,
      unidadeMedida: json['unidade_medida'] as String? ?? 'UNIDADE',
      estadoConservacao: json['estado_conservacao'] as String? ?? 'BOM',
      status: json['status'] as String? ?? 'DISPONIVEL',
      observacoes: json['observacoes'] as String?,
      caracteristicas: json['caracteristicas'] as Map<String, dynamic>?,
      subgrupoId: json['subgrupo_id'] as int?,
      localId: json['local_id'] as int?,
      parentId: json['parent_id'] as int?,
      local: json['local'] != null ? LocationModel.fromJson(json['local']) : null,
      subgrupo: json['subgrupo'] != null ? SubgroupModel.fromJson(json['subgrupo']) : null,
      componentes: json['componentes'] != null
          ? (json['componentes'] as List).map((i) => ItemModel.fromJson(i)).toList()
          : null,
      criadoEm: json['criado_em'] as String?,
      atualizadoEm: json['atualizado_em'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'bmp': bmp,
    'codigo_interno': codigoInterno,
    'numero_serie': numeroSerie,
    'tipo_controle': tipoControle,
    'quantidade': quantidade,
    'quantidade_minima': quantidadeMinima,
    'unidade_medida': unidadeMedida,
    'estado_conservacao': estadoConservacao,
    'status': status,
    'observacoes': observacoes,
    'caracteristicas': caracteristicas,
    'subgrupo_id': subgrupoId,
    'local_id': localId,
    'parent_id': parentId,
    'local': local?.toJson(),
    'subgrupo': subgrupo?.toJson(),
    'criado_em': criadoEm,
    'atualizado_em': atualizadoEm,
  };
}

class ItemMovementModel {
  final int id;
  final int itemId;
  final int? origemLocalId;
  final int? destinoLocalId;
  final int? usuarioId;
  final String tipoMovimentacao;
  final double quantidadeMovimentada;
  final String? motivo;
  final String? criadoEm;
  final String? itemNome;
  final String? usuarioNome;
  final LocationModel? origem;
  final LocationModel? destino;

  ItemMovementModel({
    required this.id,
    required this.itemId,
    this.origemLocalId,
    this.destinoLocalId,
    this.usuarioId,
    required this.tipoMovimentacao,
    required this.quantidadeMovimentada,
    this.motivo,
    this.criadoEm,
    this.itemNome,
    this.usuarioNome,
    this.origem,
    this.destino,
  });

  factory ItemMovementModel.fromJson(Map<String, dynamic> json) {
    return ItemMovementModel(
      id: json['id'] as int,
      itemId: json['item_id'] as int,
      origemLocalId: json['origem_local_id'] as int?,
      destinoLocalId: json['destino_local_id'] as int?,
      usuarioId: json['usuario_id'] as int?,
      tipoMovimentacao: json['tipo_movimentacao'] as String? ?? 'MOVIMENTACAO',
      quantidadeMovimentada: (json['quantidade_movimentada'] as num?)?.toDouble() ?? 1.0,
      motivo: json['motivo'] as String?,
      criadoEm: (json['data_hora'] ?? json['criado_em']) as String?,
      itemNome: json['item_nome'] as String?,
      usuarioNome: json['usuario_nome'] as String?,
      origem: json['origem'] != null ? LocationModel.fromJson(json['origem']) : null,
      destino: json['destino'] != null ? LocationModel.fromJson(json['destino']) : null,
    );
  }
}

class StockMetricsModel {
  final int total;
  final int disponivel;
  final int cautelado;
  final int manutencao;
  final int baixoEstoque;

  StockMetricsModel({
    this.total = 0,
    this.disponivel = 0,
    this.cautelado = 0,
    this.manutencao = 0,
    this.baixoEstoque = 0,
  });
}
