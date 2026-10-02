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
  int? _selectedGroupId;
  int? _selectedSubgroupId;
  int? _selectedLocationId;
  bool _lowStockOnly = false;

  StockProvider(this._apiService, this._storageService);

  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  DateTime? get lastSync => _storageService.lastSync;

  String get searchQuery => _searchQuery;
  String? get selectedStatus => _selectedStatus;
  int? get selectedGroupId => _selectedGroupId;
  int? get selectedSubgroupId => _selectedSubgroupId;
  int? get selectedLocationId => _selectedLocationId;
  bool get lowStockOnly => _lowStockOnly;

  List<ItemModel> get allItems => _storageService.items;
  List<ItemModel> get items => _storageService.items;
  List<GroupModel> get groups => _storageService.groups;
  List<SubgroupModel> get subgroups => _storageService.subgroups;
  List<LocationModel> get locations => _storageService.locations;

  // Itens filtrados em 0ms diretamente da memória RAM
  List<ItemModel> get filteredItems {
    return _storageService.filterLocalItems(
      search: _searchQuery,
      status: _selectedStatus,
      groupId: _selectedGroupId,
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

  // Busca instantânea de item (para scanner ou lookup rápido)
  ItemModel? findItemByCode(String code) {
    final clean = code.trim().toLowerCase();
    if (clean.isEmpty) return null;

    for (final item in _storageService.items) {
      if (item.bmp?.toLowerCase() == clean) return item;
      if (item.codigoInterno?.toLowerCase() == clean) return item;
      if (item.numeroSerie?.toLowerCase() == clean) return item;
      if (item.id.toString() == clean) return item;
    }
    return null;
  }

  LocationModel? getLocationById(int id) {
    try {
      return locations.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
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

  void setGroup(int? groupId) {
    if (_selectedGroupId == groupId) {
      _selectedGroupId = null;
    } else {
      _selectedGroupId = groupId;
      _selectedSubgroupId = null;
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

  void clearLocationFilter() {
    _selectedLocationId = null;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedStatus = null;
    _selectedGroupId = null;
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
      final subgroups = await _apiService.fetchSubgroups();
      final locations = await _apiService.fetchLocations();

      await _storageService.persistDatabase(
        items: items,
        groups: groups,
        subgroups: subgroups,
        locations: locations,
      );
    } catch (e) {
      _syncError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- CRUD Itens ---
  Future<ItemModel> createItem(Map<String, dynamic> data) async {
    final newItem = await _apiService.createItem(data);
    final currentItems = List<ItemModel>.from(_storageService.items)..insert(0, newItem);
    await _storageService.persistDatabase(items: currentItems);
    notifyListeners();
    return newItem;
  }

  Future<ItemModel> updateItem(int id, Map<String, dynamic> data) async {
    final updated = await _apiService.updateItem(id, data);
    final currentItems = List<ItemModel>.from(_storageService.items);
    final index = currentItems.indexWhere((i) => i.id == id);
    if (index != -1) {
      currentItems[index] = updated;
    } else {
      currentItems.add(updated);
    }
    await _storageService.persistDatabase(items: currentItems);
    notifyListeners();
    return updated;
  }

  Future<void> deleteItem(int id) async {
    await _apiService.deleteItem(id);
    final currentItems = List<ItemModel>.from(_storageService.items)..removeWhere((i) => i.id == id);
    await _storageService.persistDatabase(items: currentItems);
    notifyListeners();
  }

  // --- CRUD Locais ---
  Future<LocationModel> createLocation(Map<String, dynamic> data) async {
    final newLoc = await _apiService.createLocation(data);
    final currentLocs = List<LocationModel>.from(_storageService.locations)..add(newLoc);
    await _storageService.persistDatabase(items: _storageService.items, locations: currentLocs);
    notifyListeners();
    return newLoc;
  }

  Future<LocationModel> updateLocation(int id, Map<String, dynamic> data) async {
    final updated = await _apiService.updateLocation(id, data);
    final currentLocs = List<LocationModel>.from(_storageService.locations);
    final idx = currentLocs.indexWhere((l) => l.id == id);
    if (idx != -1) {
      currentLocs[idx] = updated;
    } else {
      currentLocs.add(updated);
    }
    await _storageService.persistDatabase(items: _storageService.items, locations: currentLocs);
    notifyListeners();
    return updated;
  }

  Future<void> deleteLocation(int id) async {
    await _apiService.deleteLocation(id);
    final currentLocs = List<LocationModel>.from(_storageService.locations)..removeWhere((l) => l.id == id);
    await _storageService.persistDatabase(items: _storageService.items, locations: currentLocs);
    notifyListeners();
  }

  // --- CRUD Grupos e Subgrupos ---
  Future<GroupModel> createGroup(String nome, String? descricao) async {
    final newGroup = await _apiService.createGroup({'nome': nome, 'descricao': descricao});
    final currentGroups = List<GroupModel>.from(_storageService.groups)..add(newGroup);
    await _storageService.persistDatabase(items: _storageService.items, groups: currentGroups);
    notifyListeners();
    return newGroup;
  }

  Future<GroupModel> updateGroup(int id, String nome, String? descricao) async {
    final updated = await _apiService.updateGroup(id, {'nome': nome, 'descricao': descricao});
    final currentGroups = List<GroupModel>.from(_storageService.groups);
    final idx = currentGroups.indexWhere((g) => g.id == id);
    if (idx != -1) {
      currentGroups[idx] = updated;
    } else {
      currentGroups.add(updated);
    }
    await _storageService.persistDatabase(items: _storageService.items, groups: currentGroups);
    notifyListeners();
    return updated;
  }

  Future<void> deleteGroup(int id) async {
    await _apiService.deleteGroup(id);
    final currentGroups = List<GroupModel>.from(_storageService.groups)..removeWhere((g) => g.id == id);
    await _storageService.persistDatabase(items: _storageService.items, groups: currentGroups);
    notifyListeners();
  }

  Future<SubgroupModel> createSubgroup(String nome, int grupoId, String? descricao) async {
    final newSub = await _apiService.createSubgroup({'nome': nome, 'grupo_id': grupoId, 'descricao': descricao});
    final currentSubs = List<SubgroupModel>.from(_storageService.subgroups)..add(newSub);
    await _storageService.persistDatabase(items: _storageService.items, subgroups: currentSubs);
    notifyListeners();
    return newSub;
  }

  Future<SubgroupModel> updateSubgroup(int id, String nome, int grupoId, String? descricao) async {
    final updated = await _apiService.updateSubgroup(id, {'nome': nome, 'grupo_id': grupoId, 'descricao': descricao});
    final currentSubs = List<SubgroupModel>.from(_storageService.subgroups);
    final idx = currentSubs.indexWhere((s) => s.id == id);
    if (idx != -1) {
      currentSubs[idx] = updated;
    } else {
      currentSubs.add(updated);
    }
    await _storageService.persistDatabase(items: _storageService.items, subgroups: currentSubs);
    notifyListeners();
    return updated;
  }

  Future<void> deleteSubgroup(int id) async {
    await _apiService.deleteSubgroup(id);
    final currentSubs = List<SubgroupModel>.from(_storageService.subgroups)..removeWhere((s) => s.id == id);
    await _storageService.persistDatabase(items: _storageService.items, subgroups: currentSubs);
    notifyListeners();
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
