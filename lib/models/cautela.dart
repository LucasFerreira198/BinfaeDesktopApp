import 'item.dart';
import 'user.dart';

class CautelaItemModel {
  final int id;
  final int cautelaId;
  final int itemId;
  final ItemModel? item;
  final MilitaryModel? militarResponsavel;
  final UserModel? usuarioEntrega;
  final UserModel? usuarioDevolucao;
  final DateTime dataSaida;
  final DateTime? dataDevolucao;
  final String status; // CAUTELADO ou DEVOLVIDO
  final String? condicaoSaida;
  final String? condicaoRetorno;
  final String? observacoes;

  final int? militarSaramRaw;
  final String? telefoneContatoRaw;

  CautelaItemModel({
    required this.id,
    required this.cautelaId,
    required this.itemId,
    this.item,
    this.militarResponsavel,
    this.usuarioEntrega,
    this.usuarioDevolucao,
    required this.dataSaida,
    this.dataDevolucao,
    required this.status,
    this.condicaoSaida,
    this.condicaoRetorno,
    this.observacoes,
    this.militarSaramRaw,
    this.telefoneContatoRaw,
  });

  factory CautelaItemModel.fromJson(Map<String, dynamic> json) {
    MilitaryModel? mil;
    if (json['militar_responsavel'] != null) {
      mil = MilitaryModel.fromJson(json['militar_responsavel']);
    } else if (json['militar'] != null) {
      mil = MilitaryModel.fromJson(json['militar']);
    }

    return CautelaItemModel(
      id: json['id'] as int? ?? 0,
      cautelaId: json['cautela_id'] as int? ?? 0,
      itemId: json['item_id'] as int? ?? 0,
      item: json['item'] != null ? ItemModel.fromJson(json['item']) : null,
      militarResponsavel: mil,
      usuarioEntrega: json['usuario_entrega'] != null
          ? UserModel.fromJson(json['usuario_entrega'])
          : null,
      usuarioDevolucao: json['usuario_devolucao'] != null
          ? UserModel.fromJson(json['usuario_devolucao'])
          : null,
      dataSaida: json['data_saida'] != null
          ? DateTime.parse(json['data_saida'])
          : (json['data_cautela'] != null ? DateTime.parse(json['data_cautela']) : DateTime.now()),
      dataDevolucao: json['data_devolucao'] != null
          ? DateTime.tryParse(json['data_devolucao'])
          : null,
      status: json['status'] as String? ?? 'CAUTELADO',
      condicaoSaida: json['condicao_saida'] as String?,
      condicaoRetorno: json['condicao_retorno'] as String?,
      observacoes: json['observacoes'] as String?,
      militarSaramRaw: json['militar_saram'] as int?,
      telefoneContatoRaw: json['telefone_contato'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cautela_id': cautelaId,
    'item_id': itemId,
    'item': item?.toJson(),
    'militar_responsavel': militarResponsavel?.toJson(),
    'usuario_entrega': usuarioEntrega?.toJson(),
    'usuario_devolucao': usuarioDevolucao?.toJson(),
    'data_saida': dataSaida.toIso8601String(),
    'data_devolucao': dataDevolucao?.toIso8601String(),
    'status': status,
    'condicao_saida': condicaoSaida,
    'condicao_retorno': condicaoRetorno,
    'observacoes': observacoes,
    'militar_saram': militarSaramRaw ?? militarResponsavel?.saram,
    'telefone_contato': telefoneContatoRaw ?? militarResponsavel?.celular,
  };

  MilitaryModel? get militar => militarResponsavel;
  String get militarSaram => (militarSaramRaw != null ? militarSaramRaw.toString() : (militarResponsavel?.saram.toString() ?? ''));
  String? get telefoneContato => telefoneContatoRaw ?? militarResponsavel?.celular;
  DateTime get dataCautela => dataSaida;
}

class CautelaModel {
  final int id;
  final String nome;
  final String tipo; // MISSAO ou FIXA
  final String status; // ATIVA ou CONCLUIDA
  final DateTime dataInicio;
  final DateTime? dataFim;
  final int? criadoPorUsuarioId;
  final UserModel? criadoPor;
  final String? observacoes;
  final int totalItens;
  final int itensCautelados;
  final int itensDevolvidos;
  final List<CautelaItemModel> itens;

  CautelaModel({
    required this.id,
    required this.nome,
    this.tipo = 'MISSAO',
    this.status = 'ATIVA',
    required this.dataInicio,
    this.dataFim,
    this.criadoPorUsuarioId,
    this.criadoPor,
    this.observacoes,
    this.totalItens = 0,
    this.itensCautelados = 0,
    this.itensDevolvidos = 0,
    this.itens = const [],
  });

  factory CautelaModel.fromJson(Map<String, dynamic> json) {
    var rawItens = json['itens'] as List? ?? [];
    var itensList = rawItens.map((i) => CautelaItemModel.fromJson(i as Map<String, dynamic>)).toList();

    return CautelaModel(
      id: json['id'] as int? ?? 0,
      nome: json['nome'] as String? ?? 'Sem nome',
      tipo: json['tipo'] as String? ?? 'MISSAO',
      status: json['status'] as String? ?? 'ATIVA',
      dataInicio: json['data_inicio'] != null
          ? DateTime.parse(json['data_inicio'])
          : DateTime.now(),
      dataFim: json['data_fim'] != null ? DateTime.tryParse(json['data_fim']) : null,
      criadoPorUsuarioId: json['criado_por_usuario_id'] as int?,
      criadoPor: json['criado_por'] != null ? UserModel.fromJson(json['criado_por']) : null,
      observacoes: json['observacoes'] as String?,
      totalItens: json['total_itens'] as int? ?? itensList.length,
      itensCautelados: json['itens_cautelados'] as int? ??
          itensList.where((i) => i.status == 'CAUTELADO').length,
      itensDevolvidos: json['itens_devolvidos'] as int? ??
          itensList.where((i) => i.status == 'DEVOLVIDO').length,
      itens: itensList,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'tipo': tipo,
    'status': status,
    'data_inicio': dataInicio.toIso8601String(),
    'data_fim': dataFim?.toIso8601String(),
    'criado_por_usuario_id': criadoPorUsuarioId,
    'criado_por': criadoPor?.toJson(),
    'observacoes': observacoes,
    'total_itens': totalItens,
    'itens_cautelados': itensCautelados,
    'itens_devolvidos': itensDevolvidos,
    'itens': itens.map((i) => i.toJson()).toList(),
  };

  UserModel? get criador => criadoPor;
  int get itensPendentes => itensCautelados;
}
