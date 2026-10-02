import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class StockProvider extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  bool _isSyncing = false;
  String? _syncError;

  // Filtros ativos
  String _searchQuery = '';
  String? _selectedStatus;
  int? _selectedSubgroupId;
  int? _selectedLocationId;
  bool _lowStockOnly = false;

  StockProvider(this._apiService, this._storageService);

  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  DateTime? get lastSync => _storageService.lastSync;

  String get searchQuery => _searchQuery;
  String? get selectedStatus => _selectedStatus;
  int? get selectedSubgroupId => _selectedSubgroupId;
  int? get selectedLocationId => _selectedLocationId;
  bool get lowStockOnly => _lowStockOnly;

  List<ItemModel> get allItems => _storageService.items;
  List<GroupModel> get groups => _storageService.groups;
  List<LocationModel> get locations => _storageService.locations;

  // Itens filtrados em 0ms diretamente da memória RAM
  List<ItemModel> get filteredItems {
    return _storageService.filterLocalItems(
      search: _searchQuery,
      status: _selectedStatus,
      subgroupId: _selectedSubgroupId,
      locationId: _selectedLocationId,
      lowStockOnly: _lowStockOnly,
    );
  }

  // Métricas de estoque calculadas em 0ms
  StockMetricsModel get metrics => _storageService.calculateMetrics();

  Future<void> init() async {
    await _storageService.loadLocalDatabase();
    notifyListeners();
  }

  // Métodos de filtro com resposta instantânea em 0ms
  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatus(String? status) {
    if (_selectedStatus == status) {
      _selectedStatus = null;
    } else {
      _selectedStatus = status;
    }
    notifyListeners();
  }

  void setSubgroup(int? subgroupId) {
    if (_selectedSubgroupId == subgroupId) {
      _selectedSubgroupId = null;
    } else {
      _selectedSubgroupId = subgroupId;
    }
    notifyListeners();
  }

  void setLocation(int? locationId) {
    if (_selectedLocationId == locationId) {
      _selectedLocationId = null;
    } else {
      _selectedLocationId = locationId;
    }
    notifyListeners();
  }

  void toggleLowStockOnly() {
    _lowStockOnly = !_lowStockOnly;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedStatus = null;
    _selectedSubgroupId = null;
    _selectedLocationId = null;
    _lowStockOnly = false;
    notifyListeners();
  }

  // Sincronização em segundo plano com a API
  Future<void> syncData() async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final items = await _apiService.fetchItems();
      final groups = await _apiService.fetchGroups();
      final locations = await _apiService.fetchLocations();

      await _storageService.persistDatabase(
        items: items,
        groups: groups,
        locations: locations,
      );
    } catch (e) {
      _syncError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Movimentação de material com atualização imediata em memória
  Future<void> moveItem({
    required int itemId,
    required String tipoMovimentacao,
    required double quantidade,
    int? destinoLocalId,
    String? motivo,
  }) async {
    final updated = await _apiService.moveItem(
      itemId: itemId,
      tipoMovimentacao: tipoMovimentacao,
      quantidade: quantidade,
      destinoLocalId: destinoLocalId,
      motivo: motivo,
    );

    final currentItems = List<ItemModel>.from(_storageService.items);
    final index = currentItems.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      currentItems[index] = updated;
    } else {
      currentItems.add(updated);
    }

    await _storageService.persistDatabase(items: currentItems);
    notifyListeners();
  }
}
