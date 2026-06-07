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

  Future<void> addMotor(Motor motor) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.post('/motors', {
        'nama': motor.nama,
        'kategori': motor.kategori,
        'harga': motor.harga,
        'deskripsi': motor.deskripsi,
        'gambar': motor.gambar,
        'status': motor.status,
      });
      await fetchMotors();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMotor(Motor motor) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/motors/${motor.id}', {
        'nama': motor.nama,
        'kategori': motor.kategori,
        'harga': motor.harga,
        'deskripsi': motor.deskripsi,
        'gambar': motor.gambar,
        'status': motor.status,
      });
      await fetchMotors();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMotor(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.delete('/motors/$id');
      await fetchMotors();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
