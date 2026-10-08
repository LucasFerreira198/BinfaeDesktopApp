import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../models/cautela.dart';
import '../models/pendencia.dart';
import '../models/escala.dart';
import '../models/relatorio_diario.dart';
import '../models/config_ti.dart';

class AppHttpOverrides extends HttpOverrides {
  final bool enabled;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final bool bypassSsl;

  AppHttpOverrides({
    required this.enabled,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypassSsl = true,
  });

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    if (enabled && host.trim().isNotEmpty) {
      final cleanHost = host.trim();
      client.findProxy = (uri) {
        return "PROXY $cleanHost:$port";
      };
      if (username != null && username!.trim().isNotEmpty) {
        final cleanUser = username!.trim();
        final cleanPass = password ?? '';
        client.authenticateProxy = (String h, int p, String scheme, String? realm) async {
          client.addProxyCredentials(
            h,
            p,
            realm ?? '',
            HttpClientBasicCredentials(cleanUser, cleanPass),
          );
          return true;
        };
      }
    }
    if (bypassSsl) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    }
    return client;
  }
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String defaultBaseUrl = 'https://backend-info-binfae.vercel.app';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const String _keyBaseUrl = 'binfae_desktop_api_url';
  static const String _keyToken = 'binfae_desktop_token';
  static const String _keyRefreshToken = 'binfae_desktop_refresh_token';
  static const String _keyLoginTimestamp = 'binfae_desktop_login_timestamp';
  static const String _keyRememberMe = 'binfae_desktop_remember_me';
  static const String _keySavedUsername = 'binfae_desktop_saved_username';

  // Chaves de Configuração de Proxy Corporativo
  static const String _keyProxyEnabled = 'binfae_desktop_proxy_enabled';
  static const String _keyProxyHost = 'binfae_desktop_proxy_host';
  static const String _keyProxyPort = 'binfae_desktop_proxy_port';
  static const String _keyProxyUsername = 'binfae_desktop_proxy_username';
  static const String _keyProxyPassword = 'binfae_desktop_proxy_password';
  static const String _keyProxyBypassSsl = 'binfae_desktop_proxy_bypass_ssl';

  String _baseUrl = defaultBaseUrl;
  String? _token;
  String? _refreshToken;
  DateTime? _loginTimestamp;
  bool _rememberMe = true;

  // Estado do Proxy
  bool _proxyEnabled = false;
  String _proxyHost = '';
  int _proxyPort = 8080;
  String _proxyUsername = '';
  String _proxyPassword = '';
  bool _proxyBypassSsl = true;

  Function()? onSessionExpired;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  String? get refreshTokenStr => _refreshToken;
  DateTime? get loginTimestamp => _loginTimestamp;
  bool get rememberMe => _rememberMe;

  bool get proxyEnabled => _proxyEnabled;
  String get proxyHost => _proxyHost;
  int get proxyPort => _proxyPort;
  String get proxyUsername => _proxyUsername;
  String get proxyPassword => _proxyPassword;
  bool get proxyBypassSsl => _proxyBypassSsl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Carrega e ativa configurações de Proxy Corporativo imediatamente
    _proxyEnabled = prefs.getBool(_keyProxyEnabled) ?? false;
    _proxyHost = prefs.getString(_keyProxyHost) ?? '';
    _proxyPort = prefs.getInt(_keyProxyPort) ?? 8080;
    _proxyUsername = prefs.getString(_keyProxyUsername) ?? '';
    _proxyPassword = prefs.getString(_keyProxyPassword) ?? '';
    _proxyBypassSsl = prefs.getBool(_keyProxyBypassSsl) ?? true;
    applyProxyOverrides();

    final savedUrl = prefs.getString(_keyBaseUrl);
    if (savedUrl != null && savedUrl.trim().isNotEmpty && !savedUrl.contains('onrender.com')) {
      _baseUrl = savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
    } else {
      _baseUrl = defaultBaseUrl;
      if (savedUrl != null && savedUrl.contains('onrender.com')) {
        await prefs.setString(_keyBaseUrl, defaultBaseUrl);
      }
    }

    final savedRememberMe = prefs.getBool(_keyRememberMe) ?? false;
    _rememberMe = savedRememberMe;

    // Se a opção "Lembrar" NÃO estiver marcada, ao reabrir o app o login é exigido imediatamente
    if (!_rememberMe) {
      await clearAuthSession(preserveSavedUsername: true);
      return;
    }

    _token = prefs.getString(_keyToken);
    _refreshToken = prefs.getString(_keyRefreshToken);

    final rawTimestamp = prefs.getString(_keyLoginTimestamp);
    if (rawTimestamp != null) {
      _loginTimestamp = DateTime.tryParse(rawTimestamp);
      // Se tiver passado mais de 24 horas desde o login, encerra a sessão
      if (_loginTimestamp != null &&
          DateTime.now().difference(_loginTimestamp!).inHours >= 24) {
        await clearAuthSession(preserveSavedUsername: true);
        return;
      }
    } else {
      await clearAuthSession(preserveSavedUsername: true);
      return;
    }
  }

  void applyProxyOverrides() {
    if (_proxyEnabled && _proxyHost.trim().isNotEmpty) {
      HttpOverrides.global = AppHttpOverrides(
        enabled: true,
        host: _proxyHost,
        port: _proxyPort,
        username: _proxyUsername,
        password: _proxyPassword,
        bypassSsl: _proxyBypassSsl,
      );
    } else {
      if (_proxyBypassSsl) {
        HttpOverrides.global = AppHttpOverrides(
          enabled: false,
          host: '',
          port: 8080,
          bypassSsl: true,
        );
      } else {
        HttpOverrides.global = null;
      }
    }
  }

  Future<void> saveProxySettings({
    required bool enabled,
    required String host,
    required int port,
    required String username,
    required String password,
    bool bypassSsl = true,
  }) async {
    _proxyEnabled = enabled;
    _proxyHost = host.trim();
    _proxyPort = port;
    _proxyUsername = username.trim();
    _proxyPassword = password;
    _proxyBypassSsl = bypassSsl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProxyEnabled, _proxyEnabled);
    await prefs.setString(_keyProxyHost, _proxyHost);
    await prefs.setInt(_keyProxyPort, _proxyPort);
    await prefs.setString(_keyProxyUsername, _proxyUsername);
    await prefs.setString(_keyProxyPassword, _proxyPassword);
    await prefs.setBool(_keyProxyBypassSsl, _proxyBypassSsl);

    applyProxyOverrides();
  }

  Future<bool> testProxy({
    required bool enabled,
    required String host,
    required int port,
    String? username,
    String? password,
    bool bypassSsl = true,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = requestTimeout;
    if (enabled && host.trim().isNotEmpty) {
      client.findProxy = (uri) => "PROXY ${host.trim()}:$port";
      if (username != null && username.trim().isNotEmpty) {
        client.authenticateProxy = (h, p, scheme, realm) async {
          client.addProxyCredentials(
            h,
            p,
            realm ?? '',
            HttpClientBasicCredentials(username.trim(), password ?? ''),
          );
          return true;
        };
      }
    }
    if (bypassSsl) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/'));
      final response = await request.close().timeout(requestTimeout);
      client.close();
      return response.statusCode < 500;
    } catch (e) {
      client.close();
      rethrow;
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
      if (_rememberMe) {
        await prefs.setString(_keyToken, token);
        if (_loginTimestamp == null) {
          _loginTimestamp = DateTime.now();
          await prefs.setString(_keyLoginTimestamp, _loginTimestamp!.toIso8601String());
        }
      }
    } else {
      await prefs.remove(_keyToken);
    }
  }

  Future<void> setRefreshToken(String? refreshToken) async {
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    if (refreshToken != null) {
      if (_rememberMe) {
        await prefs.setString(_keyRefreshToken, refreshToken);
      }
    } else {
      await prefs.remove(_keyRefreshToken);
    }
  }

  Future<void> clearAuthSession({bool preserveSavedUsername = true}) async {
    _token = null;
    _refreshToken = null;
    _loginTimestamp = null;
    _rememberMe = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyLoginTimestamp);
    await prefs.remove(_keyRememberMe);
    await prefs.remove('binfae_desktop_user');
    if (!preserveSavedUsername) {
      await prefs.remove(_keySavedUsername);
    }
  }

  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedUsername);
  }

  Future<bool> getSavedRememberMePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? true;
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
      ).timeout(requestTimeout);

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

  Future<void> _ensureAuth() async {
    if (_token == null || _token!.trim().isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedToken = prefs.getString(_keyToken);
        if (savedToken != null && savedToken.trim().isNotEmpty) {
          _token = savedToken.trim();
          _refreshToken = prefs.getString(_keyRefreshToken);
          final rawTimestamp = prefs.getString(_keyLoginTimestamp);
          if (rawTimestamp != null) {
            _loginTimestamp = DateTime.tryParse(rawTimestamp);
          }
        }
      } catch (_) {}
    }
  }

  Map<String, String> _headers([bool isJson = true]) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (_token != null && _token!.trim().isNotEmpty) {
      // Se houver timestamp de login e ultrapassar 24h, expira a sessão
      if (_loginTimestamp != null &&
          DateTime.now().difference(_loginTimestamp!).inHours >= 24) {
        _token = null;
        clearAuthSession();
        onSessionExpired?.call();
      } else {
        headers['Authorization'] = 'Bearer ${_token!.trim()}';
      }
    }
    return headers;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/'))
          .timeout(requestTimeout);
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password, {bool rememberMe = true}) async {
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
    ).timeout(requestTimeout);

    if (response.statusCode != 200) {
      String msg = 'Credenciais incorretas';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded['detail'] != null) msg = decoded['detail'];
      } catch (_) {}
      throw Exception(msg);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _rememberMe = rememberMe;
    _token = data['access_token'] as String?;
    _refreshToken = data['refresh_token'] as String?;
    _loginTimestamp = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, rememberMe);
    await prefs.setString(_keySavedUsername, username.trim());

    if (rememberMe) {
      if (_token != null) {
        await prefs.setString(_keyToken, _token!);
      }
      if (_refreshToken != null) {
        await prefs.setString(_keyRefreshToken, _refreshToken!);
      }
      await prefs.setString(_keyLoginTimestamp, _loginTimestamp!.toIso8601String());
    } else {
      // Sessão temporária em memória: limpa dados do disco para exigir login ao fechar o app
      await prefs.remove(_keyToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyLoginTimestamp);
    }
    return data;
  }

  Future<UserModel> getMe() async {
    final uri = Uri.parse('$_baseUrl/auth/me');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Sessão expirada. Faça login novamente.');
    }
    return UserModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<UserModel> updateMe({
    String? fotoUrl,
    String? password,
    String? celular,
    String? email,
    String? nomeGuerra,
    String? secao,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/me');
    final Map<String, dynamic> body = {};
    if (fotoUrl != null) body['foto_url'] = fotoUrl;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (celular != null) body['celular'] = celular;
    if (email != null) body['email'] = email;
    if (nomeGuerra != null) body['nome_guerra'] = nomeGuerra;
    if (secao != null) body['secao'] = secao;

    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar dados de perfil (${response.statusCode})'));
    }
    return UserModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<Map<String, dynamic>?> getSyncStatus() async {
    try {
      final uri = Uri.parse('$_baseUrl/system/sync-status');
      final response = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<ItemModel>> fetchItems() async {
    final uri = Uri.parse('$_baseUrl/stock/items');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
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
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => GroupModel.fromJson(json)).toList();
  }

  Future<List<SubgroupModel>> fetchSubgroups() async {
    final uri = Uri.parse('$_baseUrl/stock/subgroups');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar grupo (${response.statusCode})'));
    }
    return GroupModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteGroup(int id) async {
    final uri = Uri.parse('$_baseUrl/stock/groups/$id');
    final response = await http.delete(uri, headers: _headers()).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar subgrupo (${response.statusCode})'));
    }
    return SubgroupModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteSubgroup(int id) async {
    final uri = Uri.parse('$_baseUrl/stock/subgroups/$id');
    final response = await http.delete(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir subgrupo (${response.statusCode})'));
    }
  }

  Future<List<LocationModel>> fetchLocations() async {
    final uri = Uri.parse('$_baseUrl/stock/locations');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar local (${response.statusCode})'));
    }
    return LocationModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteLocation(int id) async {
    final uri = Uri.parse('$_baseUrl/stock/locations/$id');
    final response = await http.delete(uri, headers: _headers()).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar material (${response.statusCode})'));
    }
    return ItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteItem(int id) async {
    final uri = Uri.parse('$_baseUrl/stock/items/$id');
    final response = await http.delete(uri, headers: _headers()).timeout(requestTimeout);
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
    ).timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Erro ao registrar movimentação'));
    }

    return ItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<List<ItemMovementModel>> fetchMovements({int? itemId}) async {
    final query = itemId != null ? '?item_id=$itemId' : '';
    final uri = Uri.parse('$_baseUrl/stock/movements$query');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => ItemMovementModel.fromJson(json)).toList();
  }

  // --- Gestão de Usuários (Admin) ---
  Future<List<UserModel>> listUsers() async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/users/listUsers');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
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
    String? fotoUrl,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/createUser');
    final body = <String, dynamic>{
      'password': password,
      'admin': admin,
      'ativo': ativo,
    };
    if (saram != null) body['saram'] = saram;
    if (username != null && username.isNotEmpty) body['username'] = username;
    if (fotoUrl != null && fotoUrl.isNotEmpty) body['foto_url'] = fotoUrl;

    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(requestTimeout);
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
    String? fotoUrl,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/update/$identifier');
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (admin != null) body['admin'] = admin;
    if (ativo != null) body['ativo'] = ativo;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (fotoUrl != null) body['foto_url'] = fotoUrl;

    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar usuário (${response.statusCode})'));
    }
    return UserModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteUser(dynamic identifier) async {
    final uri = Uri.parse('$_baseUrl/users/delete/$identifier');
    final response = await http.delete(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir usuário (${response.statusCode})'));
    }
  }

  // --- Gestão de Militares (Admin) ---
  Future<List<MilitaryModel>> listMilitaries() async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/military/list');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao listar efetivo militar'));
    }
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => MilitaryModel.fromJson(json)).toList();
  }

  Future<MilitaryModel> createMilitary(Map<String, dynamic> data) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/military/create');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(requestTimeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao cadastrar militar (${response.statusCode})'));
    }
    return MilitaryModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<MilitaryModel> updateMilitary(int saram, Map<String, dynamic> data) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/military/update/$saram');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao atualizar militar (${response.statusCode})'));
    }
    return MilitaryModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deleteMilitary(int saram) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/military/delete/$saram');
    final response = await http.delete(uri, headers: _headers()).timeout(requestTimeout);
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
    await _ensureAuth();
    final queryParams = <String, String>{};
    if (tipo != null && tipo.isNotEmpty) queryParams['tipo'] = tipo;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$_baseUrl/cautelas').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
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
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
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
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao devolver material'));
    }
    return CautelaItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<CautelaItemModel> scanDevolverItem(String code) async {
    final cleanCode = Uri.encodeComponent(code.trim());
    final uri = Uri.parse('$_baseUrl/cautelas/devolver/scan/$cleanCode');
    final response = await http.post(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao descautelar material via leitor'));
    }
    return CautelaItemModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<Map<String, dynamic>> checkItemCautelaStatus(String code) async {
    final cleanCode = Uri.encodeComponent(code.trim());
    final uri = Uri.parse('$_baseUrl/cautelas/item/$cleanCode/status');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao checar status do item'));
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  // ================= PENDÊNCIAS E METAS =================
  Future<List<PendenciaModel>> listPendenciasAtivas({String? tipo, String? prioridade}) async {
    await _ensureAuth();
    final params = <String, String>{};
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    if (prioridade != null && prioridade.isNotEmpty) params['prioridade'] = prioridade;

    final uri = Uri.parse('$_baseUrl/pendencias').replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => PendenciaModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<PendenciaModel>> listPendenciasConcluidas({int limit = 100}) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/pendencias/concluidas?limit=$limit');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => PendenciaModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<PendenciaModel> createPendencia(Map<String, dynamic> data) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/pendencias');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(requestTimeout);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractError(response, 'Falha ao criar pendência'));
    }
    return PendenciaModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<PendenciaModel> concluirPendencia(
    int pendenciaId, {
    required String resolucao,
    String? laudoTecnico,
    bool retornarEstoque = true,
    int? destinoLocalId,
  }) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/pendencias/$pendenciaId/concluir');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'resolucao': resolucao.trim(),
        if (laudoTecnico != null && laudoTecnico.isNotEmpty) 'laudo_tecnico': laudoTecnico.trim(),
        'retornar_estoque': retornarEstoque,
        if (destinoLocalId != null) 'destino_local_id': destinoLocalId,
      }),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao concluir pendência'));
    }
    return PendenciaModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<PendenciaModel> baixarItemPendencia(
    int pendenciaId, {
    required String justificativaBaixa,
    String? resolucao,
  }) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/pendencias/$pendenciaId/baixar-item');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'justificativa_baixa': justificativaBaixa.trim(),
        if (resolucao != null && resolucao.isNotEmpty) 'resolucao': resolucao.trim(),
      }),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao dar baixa no item'));
    }
    return PendenciaModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<void> deletePendencia(int pendenciaId) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/pendencias/$pendenciaId');
    final response = await http.delete(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response, 'Falha ao excluir pendência'));
    }
  }

  // ================= ESCALA DE SERVIÇO =================
  Future<List<Map<String, dynamic>>> listMilitaresInformatica() async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/escalas/militares');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.cast<Map<String, dynamic>>();
  }

  Future<EscalaMensalModel> getEscalaMensal(int ano, int mes) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/escalas/$ano/$mes');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao carregar escala do mês'));
    }
    return EscalaMensalModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<EscalaMensalModel> salvarEscalaMensal(int ano, int mes, Map<String, dynamic> data) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/escalas/$ano/$mes');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao salvar escala'));
    }
    return EscalaMensalModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  // ================= RELATÓRIO DIÁRIO (24 HORAS) =================
  Future<RelatorioDiarioModel> getRelatorioHoje() async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/relatorios-diarios/hoje');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao carregar relatório de hoje'));
    }
    return RelatorioDiarioModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<RelatorioDiarioModel> getRelatorioPorData(String dataStr) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/relatorios-diarios/por-data/$dataStr');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao buscar relatório por data'));
    }
    return RelatorioDiarioModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<List<RelatorioDiarioModel>> listHistoricoRelatorios({int limit = 30}) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/relatorios-diarios/historico?limit=$limit');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) return [];
    final List list = jsonDecode(utf8.decode(response.bodyBytes));
    return list.map((json) => RelatorioDiarioModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<RelatorioDiarioModel> salvarRascunhoRelatorio(
    int relatorioId, {
    String? ocorrencias,
    int? militarServicoId,
  }) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/relatorios-diarios/$relatorioId/salvar-rascunho');
    final response = await http.put(
      uri,
      headers: _headers(),
      body: jsonEncode({
        if (ocorrencias != null) 'ocorrencias_militar': ocorrencias,
        if (militarServicoId != null) 'militar_servico_id': militarServicoId,
      }),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao salvar rascunho'));
    }
    return RelatorioDiarioModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<RelatorioDiarioModel> lancarRelatorio(
    int relatorioId, {
    String? ocorrencias,
    int? militarServicoId,
    bool enviarEmail = true,
    bool enviarWhatsapp = false,
  }) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/relatorios-diarios/$relatorioId/lancar');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        if (ocorrencias != null) 'ocorrencias_militar': ocorrencias,
        if (militarServicoId != null) 'militar_servico_id': militarServicoId,
        'enviar_email': enviarEmail,
        'enviar_whatsapp': enviarWhatsapp,
      }),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao lançar relatório'));
    }
    return RelatorioDiarioModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  // ================= CONFIGURAÇÕES TI (ADMIN) =================
  Future<InformaticaConfigModel> getConfigTI() async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/admin/config-ti');
    final response = await http.get(uri, headers: _headers()).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao carregar configurações da TI'));
    }
    return InformaticaConfigModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  Future<InformaticaConfigModel> updateConfigTI(Map<String, dynamic> data) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/admin/config-ti');
    final response = await http.put(
      uri,
      headers: _headers(),
      body: jsonEncode(data),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao salvar configurações da TI'));
    }
    return InformaticaConfigModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  // ================= E-MAIL & COMUNICADOS ADMIN =================
  Future<Map<String, dynamic>> testarEmail({
    String? destinatario,
    String? smtpHost,
    int? smtpPort,
    String? smtpUser,
    String? smtpPassword,
    String? smtpFrom,
  }) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/admin/config-ti/testar-email');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        if (destinatario != null && destinatario.trim().isNotEmpty) 'destinatario': destinatario.trim(),
        if (smtpHost != null && smtpHost.trim().isNotEmpty) 'smtp_host': smtpHost.trim(),
        if (smtpPort != null) 'smtp_port': smtpPort,
        if (smtpUser != null && smtpUser.trim().isNotEmpty) 'smtp_user': smtpUser.trim(),
        if (smtpPassword != null && smtpPassword.trim().isNotEmpty) 'smtp_password': smtpPassword.trim(),
        if (smtpFrom != null && smtpFrom.trim().isNotEmpty) 'smtp_from': smtpFrom.trim(),
      }),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao testar envio de e-mail'));
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enviarEmailUsuarios({
    required String assunto,
    required String mensagem,
    List<int>? usuarioIds,
    List<int>? militarIds,
    List<String>? emailsAdicionais,
  }) async {
    await _ensureAuth();
    final uri = Uri.parse('$_baseUrl/admin/config-ti/enviar-email');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'assunto': assunto.trim(),
        'mensagem': mensagem.trim(),
        if (usuarioIds != null && usuarioIds.isNotEmpty) 'usuario_ids': usuarioIds,
        if (militarIds != null && militarIds.isNotEmpty) 'militar_ids': militarIds,
        if (emailsAdicionais != null && emailsAdicionais.isNotEmpty) 'emails_adicionais': emailsAdicionais,
      }),
    ).timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw Exception(_extractError(response, 'Falha ao enviar e-mail para os usuários'));
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
