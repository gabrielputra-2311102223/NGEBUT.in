import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/motor.dart';

class MotorProvider with ChangeNotifier {
  List<Motor> _motors = [];
  bool _isLoading = false;

  List<Motor> get motors => _motors;
  bool get isLoading => _isLoading;

  Future<void> fetchMotors() async {
    _isLoading = true;
    // Don't notify listeners yet to avoid unnecessary rebuilds if called in initState without postframe
    
    try {
      final response = await ApiClient.get('/motors');
      final List<dynamic> data = response;
      _motors = data.map((json) => Motor.fromJson(json)).toList();
    } catch (e) {
      _motors = [];
    }
    
    _isLoading = false;
    notifyListeners();
  }
}
