import 'package:flutter/material.dart';
import '../core/api_client.dart';

class UserProvider with ChangeNotifier {
  bool _isLoading = false;
  List<dynamic> _users = [];

  bool get isLoading => _isLoading;
  List<dynamic> get users => _users;

  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.get('/users');
      _users = List<dynamic>.from(response);
    } catch (e) {
      _users = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(int userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.delete('/users/$userId');
      _users.removeWhere((u) => u['id'] == userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
