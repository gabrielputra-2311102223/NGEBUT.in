import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> register(String nama, String email, String password) async {
    await ApiClient.post('/auth/register', {
      'nama': nama,
      'email': email,
      'password': password,
    });
    // Not returning token yet because need OTP
  }

  Future<void> verifyOtp(String email, String otp) async {
    final response = await ApiClient.post('/auth/verify-otp', {
      'email': email,
      'otp': otp,
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

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) return;
    final response = await ApiClient.put('/users/${_user!['id']}', data);
    
    // Update local user state properly without losing old keys
    final updatedUser = response['user'] as Map<String, dynamic>;
    _user = {
      ..._user!,
      ...updatedUser,
    };
    
    // Re-save token and user
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      await ApiClient.saveToken(token, _user!);
    }
    notifyListeners();
  }

  Future<void> uploadPhoto(String base64Image) async {
    if (_user == null) return;
    final response = await ApiClient.post('/users/${_user!['id']}/photo', {
      'photo': base64Image
    });
    
    // Update foto_profil without losing other data
    _user!['foto_profil'] = response['foto_profil'];
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      await ApiClient.saveToken(token, _user!);
    }
    notifyListeners();
  }

  Future<void> forgotPassword(String email) async {
    await ApiClient.post('/auth/forgot-password', {'email': email});
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    await ApiClient.post('/auth/reset-password', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword
    });
  }
}
