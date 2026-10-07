import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _keyCachedUser = 'binfae_desktop_user';

  final ApiService _apiService;
  UserModel? _user;
  bool _isLoading = true;
  String? _errorMessage;

  AuthProvider(this._apiService) {
    _apiService.onSessionExpired = () {
      logout();
    };
  }

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null && _apiService.token != null;
  bool get isAdmin => _user?.admin ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.init();
      final prefs = await SharedPreferences.getInstance();

      // Se o token for nulo (ou tiver expirado o limite de 24h na inicialização do ApiService)
      if (_apiService.token == null) {
        _user = null;
        await prefs.remove(_keyCachedUser);
      } else {
        // Restaura usuário cacheado para não deslogar imediatamente ao reabrir o app
        final cachedUserStr = prefs.getString(_keyCachedUser);
        if (cachedUserStr != null && cachedUserStr.isNotEmpty) {
          try {
            _user = UserModel.fromJson(jsonDecode(cachedUserStr));
          } catch (_) {}
        }

        // Valida ou atualiza os dados do usuário em background
        try {
          final freshUser = await _apiService.getMe();
          _user = freshUser;
          if (_apiService.rememberMe) {
            await prefs.setString(_keyCachedUser, jsonEncode(freshUser.toJson()));
          }
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('401') || errStr.contains('expirada')) {
            // Tenta renovar pelo refresh_token
            final refreshed = await _apiService.refreshToken();
            if (refreshed) {
              try {
                final freshUser = await _apiService.getMe();
                _user = freshUser;
                if (_apiService.rememberMe) {
                  await prefs.setString(_keyCachedUser, jsonEncode(freshUser.toJson()));
                }
              } catch (_) {}
            } else {
              // Refresh falhou ou sessão expirou (> 24h)
              await _apiService.clearAuthSession();
              await prefs.remove(_keyCachedUser);
              _user = null;
            }
          }
          // Caso seja erro de rede/timeout do Render, mantém o _user cacheado
        }
      }
    } catch (_) {
      // Falha genérica não deve deslogar se houver cache válido e token
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password, {bool rememberMe = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.login(username, password, rememberMe: rememberMe);
      final freshUser = await _apiService.getMe();
      _user = freshUser;

      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString(_keyCachedUser, jsonEncode(freshUser.toJson()));
      } else {
        await prefs.remove(_keyCachedUser);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<UserModel> updateProfile({
    String? fotoUrl,
    String? password,
    String? celular,
    String? email,
    String? nomeGuerra,
    String? secao,
  }) async {
    final updated = await _apiService.updateMe(
      fotoUrl: fotoUrl,
      password: password,
      celular: celular,
      email: email,
      nomeGuerra: nomeGuerra,
      secao: secao,
    );
    _user = updated;
    final prefs = await SharedPreferences.getInstance();
    if (_apiService.rememberMe) {
      await prefs.setString(_keyCachedUser, jsonEncode(updated.toJson()));
    }
    notifyListeners();
    return updated;
  }

  Future<void> refreshUser() async {
    try {
      final fresh = await _apiService.getMe();
      _user = fresh;
      final prefs = await SharedPreferences.getInstance();
      if (_apiService.rememberMe) {
        await prefs.setString(_keyCachedUser, jsonEncode(fresh.toJson()));
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _apiService.clearAuthSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCachedUser);
    _user = null;
    notifyListeners();
  }
}

