import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/cautela.dart';
import '../models/pendencia.dart';
import '../models/relatorio_diario.dart';
import '../models/config_ti.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyItems = 'binfae_desktop_cached_items';
  static const String _keyGroups = 'binfae_desktop_cached_groups';
  static const String _keySubgroups = 'binfae_desktop_cached_subgroups';
  static const String _keyLocations = 'binfae_desktop_cached_locations';
  static const String _keyCautelas = 'binfae_desktop_cached_cautelas';
  static const String _keyPendenciasAtivas = 'binfae_desktop_cached_pendencias_ativas';
  static const String _keyPendenciasConcluidas = 'binfae_desktop_cached_pendencias_concluidas';
  static const String _keyMilitares = 'binfae_desktop_cached_militares';
  static const String _keyUltimoRelatorio = 'binfae_desktop_cached_ultimo_relatorio';
  static const String _keyConfigTI = 'binfae_desktop_cached_config_ti';
  static const String _keyLastSync = 'binfae_desktop_last_sync';

  List<ItemModel> _memoryItems = [];
  List<GroupModel> _memoryGroups = [];
  List<SubgroupModel> _memorySubgroups = [];
  List<LocationModel> _memoryLocations = [];
  List<CautelaModel> _memoryCautelas = [];
  List<PendenciaModel> _memoryPendenciasAtivas = [];
  List<PendenciaModel> _memoryPendenciasConcluidas = [];
  List<Map<String, dynamic>> _memoryMilitares = [];
  RelatorioDiarioModel? _memoryUltimoRelatorio;
  InformaticaConfigModel? _memoryConfigTI;
  DateTime? _lastSync;

  List<ItemModel> get items => _memoryItems;
  List<GroupModel> get groups => _memoryGroups;
  List<SubgroupModel> get subgroups => _memorySubgroups;
  List<LocationModel> get locations => _memoryLocations;
  List<CautelaModel> get cautelas => _memoryCautelas;
  List<PendenciaModel> get pendenciasAtivas => _memoryPendenciasAtivas;
  List<PendenciaModel> get pendenciasConcluidas => _memoryPendenciasConcluidas;
  List<Map<String, dynamic>> get militares => _memoryMilitares;
  RelatorioDiarioModel? get ultimoRelatorio => _memoryUltimoRelatorio;
  InformaticaConfigModel? get configTI => _memoryConfigTI;
  DateTime? get lastSync => _lastSync;

  /// Retorna o caminho do arquivo físico permanente de backup local no Windows/sistema.
  /// Salvo em: %USERPROFILE%\Documents\BINFAE_Backups\binfae_backup_local.json
  static File _getPermanentBackupFile() {
    String basePath = '';
    final sep = Platform.pathSeparator;
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (userProfile != null && userProfile.isNotEmpty) {
        basePath = '$userProfile${sep}Documents${sep}BINFAE_Backups';
      }
    }
    if (basePath.isEmpty) {
      basePath = '${Directory.current.path}${sep}BINFAE_Backups';
    }
    final dir = Directory(basePath);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return File('$basePath${sep}binfae_backup_local.json');
  }

  Future<void> loadLocalDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawItems = prefs.getString(_keyItems);
      final rawGroups = prefs.getString(_keyGroups);
      final rawSubgroups = prefs.getString(_keySubgroups);
      final rawLocations = prefs.getString(_keyLocations);
      final rawCautelas = prefs.getString(_keyCautelas);
      final rawAtivas = prefs.getString(_keyPendenciasAtivas);
      final rawConcluidas = prefs.getString(_keyPendenciasConcluidas);
      final rawMilitares = prefs.getString(_keyMilitares);
      final rawRelatorio = prefs.getString(_keyUltimoRelatorio);
      final rawConfigTI = prefs.getString(_keyConfigTI);
      final rawSync = prefs.getString(_keyLastSync);

      if (rawItems != null) {
        final List list = jsonDecode(rawItems);
        _memoryItems = list.map((json) => ItemModel.fromJson(json)).toList();
      }

      if (rawGroups != null) {
        final List list = jsonDecode(rawGroups);
        _memoryGroups = list.map((json) => GroupModel.fromJson(json)).toList();
      }

      if (rawSubgroups != null) {
        final List list = jsonDecode(rawSubgroups);
        _memorySubgroups = list.map((json) => SubgroupModel.fromJson(json)).toList();
      }

      if (rawLocations != null) {
        final List list = jsonDecode(rawLocations);
        _memoryLocations = list.map((json) => LocationModel.fromJson(json)).toList();
      }

      if (rawCautelas != null) {
        final List list = jsonDecode(rawCautelas);
        _memoryCautelas = list.map((json) => CautelaModel.fromJson(json)).toList();
      }

      if (rawAtivas != null) {
        final List list = jsonDecode(rawAtivas);
        _memoryPendenciasAtivas = list.map((json) => PendenciaModel.fromJson(json)).toList();
      }

      if (rawConcluidas != null) {
        final List list = jsonDecode(rawConcluidas);
        _memoryPendenciasConcluidas = list.map((json) => PendenciaModel.fromJson(json)).toList();
      }

      if (rawMilitares != null) {
        final List list = jsonDecode(rawMilitares);
        _memoryMilitares = list.map((m) => Map<String, dynamic>.from(m)).toList();
      }

      if (rawRelatorio != null) {
        _memoryUltimoRelatorio = RelatorioDiarioModel.fromJson(jsonDecode(rawRelatorio));
      }

      if (rawConfigTI != null) {
        _memoryConfigTI = InformaticaConfigModel.fromJson(jsonDecode(rawConfigTI));
      }

      if (rawSync != null) {
        _lastSync = DateTime.tryParse(rawSync);
      }

      // Se o SharedPreferences estiver vazio ou com itens zerados (ex: app recém-atualizado),
      // restaura imediatamente a partir do arquivo físico permanente de backup local!
      if (_memoryItems.isEmpty) {
        await _restoreFromPermanentBackupFile();
      }
    } catch (_) {
      // Fallback: tenta recuperar do arquivo físico de backup
      await _restoreFromPermanentBackupFile();
    }
  }

  Future<void> _restoreFromPermanentBackupFile() async {
    try {
      final file = _getPermanentBackupFile();
      if (!file.existsSync()) return;
      final rawContent = await file.readAsString();
      if (rawContent.trim().isEmpty) return;

      final data = jsonDecode(rawContent) as Map<String, dynamic>;

      if (data['items'] is List && (data['items'] as List).isNotEmpty) {
        _memoryItems = (data['items'] as List).map((json) => ItemModel.fromJson(json)).toList();
      }
      if (data['groups'] is List) {
        _memoryGroups = (data['groups'] as List).map((json) => GroupModel.fromJson(json)).toList();
      }
      if (data['subgroups'] is List) {
        _memorySubgroups = (data['subgroups'] as List).map((json) => SubgroupModel.fromJson(json)).toList();
      }
      if (data['locations'] is List) {
        _memoryLocations = (data['locations'] as List).map((json) => LocationModel.fromJson(json)).toList();
      }
      if (data['cautelas'] is List) {
        _memoryCautelas = (data['cautelas'] as List).map((json) => CautelaModel.fromJson(json)).toList();
      }
      if (data['pendencias_ativas'] is List) {
        _memoryPendenciasAtivas = (data['pendencias_ativas'] as List).map((json) => PendenciaModel.fromJson(json)).toList();
      }
      if (data['pendencias_concluidas'] is List) {
        _memoryPendenciasConcluidas = (data['pendencias_concluidas'] as List).map((json) => PendenciaModel.fromJson(json)).toList();
      }
      if (data['militares'] is List) {
        _memoryMilitares = (data['militares'] as List).map((m) => Map<String, dynamic>.from(m)).toList();
      }
      if (data['ultimo_relatorio'] is Map) {
        _memoryUltimoRelatorio = RelatorioDiarioModel.fromJson(data['ultimo_relatorio']);
      }
      if (data['config_ti'] is Map) {
        _memoryConfigTI = InformaticaConfigModel.fromJson(data['config_ti']);
      }
      if (data['last_sync'] != null) {
        _lastSync = DateTime.tryParse(data['last_sync'].toString());
      }

      // Sincroniza de volta no SharedPreferences para acessos imediatos
      final prefs = await SharedPreferences.getInstance();
      if (_memoryItems.isNotEmpty) {
        await prefs.setString(_keyItems, jsonEncode(_memoryItems.map((i) => i.toJson()).toList()));
      }
      if (_memoryCautelas.isNotEmpty) {
        await prefs.setString(_keyCautelas, jsonEncode(_memoryCautelas.map((c) => c.toJson()).toList()));
      }
      if (_memoryPendenciasAtivas.isNotEmpty) {
        await prefs.setString(_keyPendenciasAtivas, jsonEncode(_memoryPendenciasAtivas.map((p) => p.toJson()).toList()));
      }
      if (_memoryPendenciasConcluidas.isNotEmpty) {
        await prefs.setString(_keyPendenciasConcluidas, jsonEncode(_memoryPendenciasConcluidas.map((p) => p.toJson()).toList()));
      }
    } catch (_) {}
  }

  void _triggerPermanentDiskBackup() {
    // Gravação assíncrona desacoplada em disco sem bloquear o fluxo principal
    Future.microtask(() async {
      try {
        final file = _getPermanentBackupFile();
        final backupData = {
          'version': 1,
          'last_sync': (_lastSync ?? DateTime.now()).toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'items': _memoryItems.map((i) => i.toJson()).toList(),
          'groups': _memoryGroups.map((g) => g.toJson()).toList(),
          'subgroups': _memorySubgroups.map((s) => s.toJson()).toList(),
          'locations': _memoryLocations.map((l) => l.toJson()).toList(),
          'cautelas': _memoryCautelas.map((c) => c.toJson()).toList(),
          'pendencias_ativas': _memoryPendenciasAtivas.map((p) => p.toJson()).toList(),
          'pendencias_concluidas': _memoryPendenciasConcluidas.map((p) => p.toJson()).toList(),
          'militares': _memoryMilitares,
          if (_memoryUltimoRelatorio != null) 'ultimo_relatorio': _memoryUltimoRelatorio!.toJson(),
          if (_memoryConfigTI != null) 'config_ti': _memoryConfigTI!.toJson(),
        };
        await file.writeAsString(jsonEncode(backupData), flush: true);
      } catch (_) {}
    });
  }

  Future<void> persistDatabase({
    required List<ItemModel> items,
    List<GroupModel>? groups,
    List<SubgroupModel>? subgroups,
    List<LocationModel>? locations,
  }) async {
    _memoryItems = items;
    _lastSync = DateTime.now();
    if (groups != null) _memoryGroups = groups;
    if (subgroups != null) _memorySubgroups = subgroups;
    if (locations != null) _memoryLocations = locations;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyItems, jsonEncode(items.map((i) => i.toJson()).toList()));
    await prefs.setString(_keyLastSync, _lastSync!.toIso8601String());

    if (groups != null) {
      await prefs.setString(_keyGroups, jsonEncode(groups.map((g) => g.toJson()).toList()));
    }
    if (subgroups != null) {
      await prefs.setString(_keySubgroups, jsonEncode(subgroups.map((s) => s.toJson()).toList()));
    }
    if (locations != null) {
      await prefs.setString(_keyLocations, jsonEncode(locations.map((l) => l.toJson()).toList()));
    }

    _triggerPermanentDiskBackup();
  }

  Future<void> persistCautelas(List<CautelaModel> cautelas) async {
    _memoryCautelas = cautelas;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCautelas, jsonEncode(cautelas.map((c) => c.toJson()).toList()));
      _triggerPermanentDiskBackup();
    } catch (_) {}
  }

  Future<void> persistPendencias({
    List<PendenciaModel>? ativas,
    List<PendenciaModel>? concluidas,
  }) async {
    if (ativas != null) _memoryPendenciasAtivas = ativas;
    if (concluidas != null) _memoryPendenciasConcluidas = concluidas;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (ativas != null) {
        await prefs.setString(_keyPendenciasAtivas, jsonEncode(ativas.map((p) => p.toJson()).toList()));
      }
      if (concluidas != null) {
        await prefs.setString(_keyPendenciasConcluidas, jsonEncode(concluidas.map((p) => p.toJson()).toList()));
      }
      _triggerPermanentDiskBackup();
    } catch (_) {}
  }

  Future<void> persistMilitares(List<Map<String, dynamic>> militares) async {
    _memoryMilitares = militares;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMilitares, jsonEncode(militares));
      _triggerPermanentDiskBackup();
    } catch (_) {}
  }

  Future<void> persistUltimoRelatorio(RelatorioDiarioModel relatorio) async {
    _memoryUltimoRelatorio = relatorio;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUltimoRelatorio, jsonEncode(relatorio.toJson()));
      _triggerPermanentDiskBackup();
    } catch (_) {}
  }

  Future<void> invalidateUltimoRelatorio() async {
    _memoryUltimoRelatorio = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUltimoRelatorio);
    } catch (_) {}
  }

  Future<void> persistConfigTI(InformaticaConfigModel config) async {
    _memoryConfigTI = config;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyConfigTI, jsonEncode(config.toJson()));
      _triggerPermanentDiskBackup();
    } catch (_) {}
  }

  List<ItemModel> filterLocalItems({
    String search = '',
    String? status,
    int? groupId,
    int? subgroupId,
    int? locationId,
    bool lowStockOnly = false,
  }) {
    final query = search.trim().toLowerCase();

    return _memoryItems.where((item) {
      if (status != null) {
        if (status == 'NO_SETOR') {
          if (!item.estaEmSetor) return false;
        } else if (status == 'NO_DEPOSITO') {
          if (!item.estaNoDeposito) return false;
        } else if (item.status != status) {
          return false;
        }
      }
      if (groupId != null && item.subgrupo?.grupoId != groupId) return false;
      if (subgroupId != null && item.subgrupoId != subgroupId) return false;
      if (locationId != null && item.localId != locationId) return false;
      if (lowStockOnly) {
        if (item.tipoControle != 'GRANEL' || item.quantidade > item.quantidadeMinima) {
          return false;
        }
      }

      if (query.isNotEmpty) {
        final matchName = item.nome.toLowerCase().contains(query);
        final matchBmp = item.bmp?.toLowerCase().contains(query) ?? false;
        final matchCode = item.codigoInterno?.toLowerCase().contains(query) ?? false;
        final matchSerial = item.numeroSerie?.toLowerCase().contains(query) ?? false;
        final matchObs = item.observacoes?.toLowerCase().contains(query) ?? false;
        final matchLoc = (item.local?.nome.toLowerCase().contains(query) ?? false) ||
                         item.localizacaoAtual.toLowerCase().contains(query);

        if (!matchName && !matchBmp && !matchCode && !matchSerial && !matchObs && !matchLoc) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  StockMetricsModel calculateMetrics() {
    int total = _memoryItems.length;
    int disponivel = 0;
    int noSetor = 0;
    int cautelado = 0;
    int manutencao = 0;
    int baixoEstoque = 0;

    for (final item in _memoryItems) {
      if (item.status == 'EM_MANUTENCAO') {
        manutencao++;
      } else if (item.status == 'CAUTELADO' || (item.cautelaAtiva != null && (item.cautelaAtiva!['tipo'] ?? '') == 'MISSAO')) {
        cautelado++;
      } else if (item.estaEmSetor) {
        noSetor++;
      } else {
        disponivel++;
      }

      if (item.tipoControle == 'GRANEL' && item.quantidade <= item.quantidadeMinima) {
        baixoEstoque++;
      }
    }

    return StockMetricsModel(
      total: total,
      disponivel: disponivel,
      noSetor: noSetor,
      cautelado: cautelado,
      manutencao: manutencao,
      baixoEstoque: baixoEstoque,
    );
  }
}
