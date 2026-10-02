import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  UserModel? _user;
  bool _isLoading = true;
  String? _errorMessage;

  AuthProvider(this._apiService);

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null && _apiService.token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.init();
      if (_apiService.token != null) {
        _user = await _apiService.getMe();
      }
    } catch (_) {
      await _apiService.setToken(null);
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.login(username, password);
      _user = await _apiService.getMe();
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

  Future<void> logout() async {
    await _apiService.setToken(null);
    _user = null;
    notifyListeners();
  }
}
