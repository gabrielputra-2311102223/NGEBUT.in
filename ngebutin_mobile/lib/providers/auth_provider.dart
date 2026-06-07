import 'package:flutter/material.dart';
import '../core/api_client.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      _user = await ApiClient.getCurrentUser();
    } catch (e) {
      _user = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await ApiClient.post('/auth/login', {
      'email': email,
      'password': password,
    });
    
    final token = response['token'];
    final user = response['user'];
    
    await ApiClient.saveToken(token, user);
    _user = user;
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.clearSession();
    _user = null;
    notifyListeners();
  }
}
