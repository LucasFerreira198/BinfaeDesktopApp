import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/user.dart';

class ApiService {
  static const String defaultBaseUrl = 'https://systeminformaticabinfae.onrender.com';
  static const String _keyBaseUrl = 'binfae_desktop_api_url';
  static const String _keyToken = 'binfae_desktop_token';

  String _baseUrl = defaultBaseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyBaseUrl);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      _baseUrl = savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
    _token = prefs.getString(_keyToken);
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
    } else {
      await prefs.remove(_keyToken);
    }
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
          .get(Uri.parse('$_baseUrl/'), headers: _headers())
          .timeout(const Duration(seconds: 4));
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

  Future<List<GroupModel>> fetchGroups() async {
    final uri = Uri.parse('$_baseUrl/stock/groups');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => GroupModel.fromJson(json)).toList();
  }

  Future<List<LocationModel>> fetchLocations() async {
    final uri = Uri.parse('$_baseUrl/stock/locations');
    final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => LocationModel.fromJson(json)).toList();
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
      String msg = 'Erro ao registrar movimentação';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded['detail'] != null) msg = decoded['detail'];
      } catch (_) {}
      throw Exception(msg);
    }

    return ItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }
}
