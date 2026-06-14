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
    _user = Map<String, dynamic>.from(user);
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

  Future<bool> verifyOtp(String email, String otp) async {
    final response = await ApiClient.post('/auth/verify-otp', {
      'email': email,
      'otp': otp,
    });

    // API returns { message } on success — no token.
    // If API also returns token+user (future proof), auto-login.
    if (response['token'] != null && response['user'] != null) {
      await ApiClient.saveToken(response['token'], response['user']);
      _user = Map<String, dynamic>.from(response['user']);
      notifyListeners();
      return true; // logged in
    }
    return false; // not logged in, redirect to login screen
  }

  Future<void> logout() async {
    await ApiClient.clearSession();
    _user = null;
    notifyListeners();
  }

  /// Fetch complete profile from server (includes email, foto_profil, etc.)
  Future<void> fetchFullProfile() async {
    if (_user == null) return;
    try {
      final id = _user!['id'];
      final response = await ApiClient.get('/users/me/$id');
      if (response != null && response['id'] != null) {
        _user = {
          ..._user!,
          ...Map<String, dynamic>.from(response),
        };
        // Persist updated user
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) await ApiClient.saveToken(token, _user!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchFullProfile error: $e');
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) return;
    try {
      final response = await ApiClient.put('/users/${_user!['id']}', data);

      // Safe update: merge response user data if available
      if (response != null && response['user'] != null) {
        final updatedUser = Map<String, dynamic>.from(response['user']);
        _user = {
          ..._user!,
          ...updatedUser,
        };
      } else {
        // Apply changes locally even if response doesn't have 'user'
        if (data.containsKey('nama')) _user!['nama'] = data['nama'];
      }

      // Re-save token and user
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        await ApiClient.saveToken(token, _user!);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('updateProfile error: $e');
      rethrow;
    }
  }

  Future<void> uploadPhoto(String base64Image) async {
    if (_user == null) return;
    try {
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
    } catch (e) {
      debugPrint('uploadPhoto error: $e');
      rethrow;
    }
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
