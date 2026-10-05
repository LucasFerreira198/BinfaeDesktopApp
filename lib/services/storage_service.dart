import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';

class StorageService {
  static const String _keyItems = 'binfae_desktop_cached_items';
  static const String _keyGroups = 'binfae_desktop_cached_groups';
  static const String _keySubgroups = 'binfae_desktop_cached_subgroups';
  static const String _keyLocations = 'binfae_desktop_cached_locations';
  static const String _keyLastSync = 'binfae_desktop_last_sync';

  List<ItemModel> _memoryItems = [];
  List<GroupModel> _memoryGroups = [];
  List<SubgroupModel> _memorySubgroups = [];
  List<LocationModel> _memoryLocations = [];
  DateTime? _lastSync;

  List<ItemModel> get items => _memoryItems;
  List<GroupModel> get groups => _memoryGroups;
  List<SubgroupModel> get subgroups => _memorySubgroups;
  List<LocationModel> get locations => _memoryLocations;
  DateTime? get lastSync => _lastSync;

  Future<void> loadLocalDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawItems = prefs.getString(_keyItems);
      final rawGroups = prefs.getString(_keyGroups);
      final rawSubgroups = prefs.getString(_keySubgroups);
      final rawLocations = prefs.getString(_keyLocations);
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

      if (rawSync != null) {
        _lastSync = DateTime.tryParse(rawSync);
      }
    } catch (e) {
      // Ignora falha de deserialização inicial
    }
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
