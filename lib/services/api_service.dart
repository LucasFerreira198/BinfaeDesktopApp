import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../models/cautela.dart';

class ApiService {
  static const String defaultBaseUrl = 'https://backend-info-binfae.vercel.app';
  static const String _keyBaseUrl = 'binfae_desktop_api_url';
  static const String _keyToken = 'binfae_desktop_token';
  static const String _keyRefreshToken = 'binfae_desktop_refresh_token';
  static const String _keyLoginTimestamp = 'binfae_desktop_login_timestamp';

  String _baseUrl = defaultBaseUrl;
  String? _token;
  String? _refreshToken;
  DateTime? _loginTimestamp;

  Function()? onSessionExpired;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  String? get refreshTokenStr => _refreshToken;
  DateTime? get loginTimestamp => _loginTimestamp;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyBaseUrl);
    if (savedUrl != null && savedUrl.trim().isNotEmpty && !savedUrl.contains('onrender.com')) {
      _baseUrl = savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
    } else {
      _baseUrl = defaultBaseUrl;
      if (savedUrl != null && savedUrl.contains('onrender.com')) {
        await prefs.setString(_keyBaseUrl, defaultBaseUrl);
      }
    }
    _token = prefs.getString(_keyToken);
    _refreshToken = prefs.getString(_keyRefreshToken);

    final rawTimestamp = prefs.getString(_keyLoginTimestamp);
    if (rawTimestamp != null) {
      _loginTimestamp = DateTime.tryParse(rawTimestamp);
      // Se tiver passado mais de 24 horas desde o login, encerra a sessão
      if (_loginTimestamp != null &&
          DateTime.now().difference(_loginTimestamp!).inHours >= 24) {
        await clearAuthSession();
        return;
      }
    }
  }

  Future<void> setBaseUrl(String url) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, cleanUrl);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_keyToken, token);
      if (_loginTimestamp == null) {
        _loginTimestamp = DateTime.now();
        await prefs.setString(_keyLoginTimestamp, _loginTimestamp!.toIso8601String());
      }
    } else {
      await prefs.remove(_keyToken);
    }
  }

  Future<void> setRefreshToken(String? refreshToken) async {
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    if (refreshToken != null) {
      await prefs.setString(_keyRefreshToken, refreshToken);
    } else {
      await prefs.remove(_keyRefreshToken);
    }
  }

  Future<void> clearAuthSession() async {
    _token = null;
    _refreshToken = null;
    _loginTimestamp = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyLoginTimestamp);
    await prefs.remove('binfae_desktop_user');
  }

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;

    // Se o login tiver mais de 24 horas, recusa o refresh e encerra a sessão
    if (_loginTimestamp != null &&
        DateTime.now().difference(_loginTimestamp!).inHours >= 24) {
      await clearAuthSession();
      onSessionExpired?.call();
      return false;
    }

    try {
      final uri = Uri.parse('$_baseUrl/auth/refresh');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': _refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newAccess != null) {
          await setToken(newAccess);
        }
        if (newRefresh != null) {
          await setRefreshToken(newRefresh);
        }
        return true;
      }
    } catch (_) {}

    // Refresh falhou
    await clearAuthSession();
    onSessionExpired?.call();
    return false;
  }

  Map<String, String> _headers([bool isJson = true]) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/'))
          .timeout(const Duration(seconds: 12));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'username': username.trim(),
        'password': password,
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      String msg = 'Credenciais incorretas';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded['detail'] != null) msg = decoded['detail'];
      } catch (_) {}
      throw Exception(msg);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await setToken(data['access_token']);
    if (data['refresh_token'] != null) {
      await setRefreshToken(data['refresh_token'] as String);
    }
    _loginTimestamp = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLoginTimestamp, _loginTimestamp!.toIso8601String());
    return data;
  }

  Future<UserModel> getMe() async {
    final uri = Uri.parse('$_baseUrl/auth/me');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    return UserModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<List<ItemModel>> fetchItems() async {
    final uri = Uri.parse('$_baseUrl/stock/items');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Falha ao obter lista de materiais (${response.statusCode})');
    }
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => ItemModel.fromJson(json)).toList();
  }

  String _extractError(http.Response response, String defaultMsg) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['detail'] != null) {
        if (decoded['detail'] is List) {
          final list = decoded['detail'] as List;
          return list.map((e) => e['msg'] ?? e.toString()).join(', ');
        }
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return defaultMsg;
  }

  Future<List<GroupModel>> fetchGroups() async {
    final uri = Uri.parse('$_baseUrl/stock/groups');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => GroupModel.fromJson(json)).toList();
  }

  Future<List<SubgroupModel>> fetchSubgroups() async {
    final uri = Uri.parse('$_baseUrl/stock/subgroups');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => SubgroupModel.fromJson(json)).toList();
  }

  Future<GroupModel> createGroup(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/stock/groups');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao criar grupo (${response.statusCode})'));
    }
    return GroupModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<GroupModel> updateGroup(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/stock/groups/$id');
    final response = await http.put(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar grupo (${response.statusCode})'));
    }
    return GroupModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteGroup(int id) async {
    final uri = Uri.parse('$_baseUrl/stock/groups/$id');
    final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir grupo (${response.statusCode})'));
    }
  }

  Future<SubgroupModel> createSubgroup(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/stock/subgroups');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao criar subgrupo (${response.statusCode})'));
    }
    return SubgroupModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<SubgroupModel> updateSubgroup(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/stock/subgroups/$id');
    final response = await http.put(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar subgrupo (${response.statusCode})'));
    }
    return SubgroupModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteSubgroup(int id) async {
    final uri = Uri.parse('$_baseUrl/stock/subgroups/$id');
    final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir subgrupo (${response.statusCode})'));
    }
  }

  Future<List<LocationModel>> fetchLocations() async {
    final uri = Uri.parse('$_baseUrl/stock/locations');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => LocationModel.fromJson(json)).toList();
  }

  Future<LocationModel> createLocation(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/stock/locations');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao criar local (${response.statusCode})'));
    }
    return LocationModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<LocationModel> updateLocation(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/stock/locations/$id');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar local (${response.statusCode})'));
    }
    return LocationModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteLocation(int id) async {
    final uri = Uri.parse('$_baseUrl/stock/locations/$id');
    final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir local (${response.statusCode})'));
    }
  }

  Future<ItemModel> createItem(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/stock/items');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao cadastrar material (${response.statusCode})'));
    }
    return ItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<ItemModel> updateItem(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/stock/items/$id');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar material (${response.statusCode})'));
    }
    return ItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteItem(int id) async {
    final uri = Uri.parse('$_baseUrl/stock/items/$id');
    final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir material (${response.statusCode})'));
    }
  }

  Future<ItemModel> moveItem({
    required int itemId,
    required String tipoMovimentacao,
    required double quantidade,
    int? destinoLocalId,
    String? motivo,
  }) async {
    final uri = Uri.parse('$_baseUrl/stock/items/$itemId/move');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'tipo_movimentacao': tipoMovimentacao,
        'quantidade_movimentada': quantidade,
        'destino_local_id': destinoLocalId,
        'motivo': motivo,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Erro ao registrar movimentação'));
    }

    return ItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<List<ItemMovementModel>> fetchMovements({int? itemId}) async {
    final query = itemId != null ? '?item_id=$itemId' : '';
    final uri = Uri.parse('$_baseUrl/stock/movements$query');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => ItemMovementModel.fromJson(json)).toList();
  }

  // --- Gestão de Usuários (Admin) ---
  Future<List<UserModel>> listUsers() async {
    final uri = Uri.parse('$_baseUrl/users/listUsers');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao listar usuários'));
    }
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => UserModel.fromJson(json)).toList();
  }

  Future<UserModel> createUser({
    int? saram,
    String? username,
    required String password,
    bool admin = false,
    bool ativo = true,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/createUser');
    final body = <String, dynamic>{
      'password': password,
      'admin': admin,
      'ativo': ativo,
    };
    if (saram != null) body['saram'] = saram;
    if (username != null && username.isNotEmpty) body['username'] = username;

    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao criar usuário (${response.statusCode})'));
    }
    return UserModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<UserModel> updateUser(
    dynamic identifier, {
    String? username,
    bool? admin,
    bool? ativo,
    String? password,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/update/$identifier');
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (admin != null) body['admin'] = admin;
    if (ativo != null) body['ativo'] = ativo;
    if (password != null && password.isNotEmpty) body['password'] = password;

    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar usuário (${response.statusCode})'));
    }
    return UserModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteUser(dynamic identifier) async {
    final uri = Uri.parse('$_baseUrl/users/delete/$identifier');
    final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir usuário (${response.statusCode})'));
    }
  }

  // --- Gestão de Militares (Admin) ---
  Future<List<MilitaryModel>> listMilitaries() async {
    final uri = Uri.parse('$_baseUrl/military/list');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao listar efetivo militar'));
    }
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => MilitaryModel.fromJson(json)).toList();
  }

  Future<MilitaryModel> createMilitary(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/military/create');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao cadastrar militar (${response.statusCode})'));
    }
    return MilitaryModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<MilitaryModel> updateMilitary(int saram, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/military/update/$saram');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar militar (${response.statusCode})'));
    }
    return MilitaryModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteMilitary(int saram) async {
    final uri = Uri.parse('$_baseUrl/military/delete/$saram');
    final response = await http.delete(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir militar (${response.statusCode})'));
    }
  }

  // --- Verificação de Versão / Auto-Updater ---
  Future<Map<String, dynamic>?> checkLatestRelease() async {
    try {
      final uri = Uri.parse('https://api.github.com/repos/LucasFerreira198/BinfaeDesktopApp/releases/latest');
      final response = await http.get(uri, headers: {
        'Accept': 'application/vnd.github.v3+json',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ============================================================================
  // CAUTELAS & MISSÕES
  // ============================================================================

  Future<List<CautelaModel>> listCautelas({String? tipo, String? status, String? search}) async {
    final queryParams = <String, String>{};
    if (tipo != null && tipo.isNotEmpty) queryParams['tipo'] = tipo;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$_baseUrl/cautelas').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        return listCautelas(tipo: tipo, status: status, search: search);
      }
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao listar cautelas'));
    }
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => CautelaModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<CautelaModel> getCautela(int id) async {
    final uri = Uri.parse('$_baseUrl/cautelas/$id');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) return getCautela(id);
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao obter detalhes da cautela'));
    }
    return CautelaModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<CautelaModel> createCautela(String nome, {String tipo = 'MISSAO', String? observacoes}) async {
    final uri = Uri.parse('$_baseUrl/cautelas');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'nome': nome.trim(),
        'tipo': tipo,
        if (observacoes != null && observacoes.isNotEmpty) 'observacoes': observacoes.trim(),
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) return createCautela(nome, tipo: tipo, observacoes: observacoes);
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao criar missão/cautela'));
    }
    return CautelaModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<CautelaItemModel> addItemToCautela(
    int cautelaId, {
    int? itemId,
    String? itemCode,
    required int militarSaram,
    String? telefoneContato,
    String? condicaoSaida,
    String? observacoes,
  }) async {
    final uri = Uri.parse('$_baseUrl/cautelas/$cautelaId/itens');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        if (itemId != null) 'item_id': itemId,
        if (itemCode != null && itemCode.isNotEmpty) 'item_code': itemCode.trim(),
        'militar_saram': militarSaram,
        if (telefoneContato != null && telefoneContato.isNotEmpty) 'telefone_contato': telefoneContato.trim(),
        'condicao_saida': condicaoSaida ?? 'BOM',
        if (observacoes != null && observacoes.isNotEmpty) 'observacoes': observacoes.trim(),
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        return addItemToCautela(
          cautelaId,
          itemId: itemId,
          itemCode: itemCode,
          militarSaram: militarSaram,
          telefoneContato: telefoneContato,
          condicaoSaida: condicaoSaida,
          observacoes: observacoes,
        );
      }
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao adicionar material à missão'));
    }
    return CautelaItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<List<CautelaItemModel>> addBatchItemsToCautela(
    int cautelaId, {
    required int militarSaram,
    String? telefoneContato,
    List<int>? itensIds,
    List<String>? itensCodes,
    String? condicaoSaida,
    String? observacoes,
  }) async {
    final uri = Uri.parse('$_baseUrl/cautelas/$cautelaId/itens/lote');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'militar_saram': militarSaram,
        if (telefoneContato != null && telefoneContato.isNotEmpty) 'telefone_contato': telefoneContato.trim(),
        if (itensIds != null && itensIds.isNotEmpty) 'itens_ids': itensIds,
        if (itensCodes != null && itensCodes.isNotEmpty) 'itens_codes': itensCodes,
        'condicao_saida': condicaoSaida ?? 'BOM',
        if (observacoes != null && observacoes.isNotEmpty) 'observacoes': observacoes.trim(),
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao adicionar materiais em lote'));
    }
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => CautelaItemModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<CautelaItemModel> devolverItemCautela(
    int cautelaId,
    int itemId, {
    String? condicaoRetorno,
    String? observacoes,
  }) async {
    final uri = Uri.parse('$_baseUrl/cautelas/$cautelaId/itens/$itemId/devolver');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        if (condicaoRetorno != null && condicaoRetorno.isNotEmpty) 'condicao_retorno': condicaoRetorno.trim(),
        if (observacoes != null && observacoes.isNotEmpty) 'observacoes': observacoes.trim(),
      }),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao devolver material'));
    }
    return CautelaItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<CautelaItemModel> scanDevolverItem(String code) async {
    final cleanCode = Uri.encodeComponent(code.trim());
    final uri = Uri.parse('$_baseUrl/cautelas/devolver/scan/$cleanCode');
    final response = await http.post(uri, headers: _headers()).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao descautelar material via leitor'));
    }
    return CautelaItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<Map<String, dynamic>> checkItemCautelaStatus(String code) async {
    final cleanCode = Uri.encodeComponent(code.trim());
    final uri = Uri.parse('$_baseUrl/cautelas/item/$cleanCode/status');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao checar status do item'));
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
