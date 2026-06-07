import 'package:flutter/material.dart';
import '../core/api_client.dart';

class BookingProvider with ChangeNotifier {
  bool _isLoading = false;
  List<dynamic> _bookings = [];

  bool get isLoading => _isLoading;
  List<dynamic> get bookings => _bookings;

  Future<void> fetchMyBookings(int userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.get('/bookings');
      final List<dynamic> allBookings = response;
      _bookings = allBookings.where((b) => b['userId'] == userId).toList();
      // Sort by newest
      _bookings.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
    } catch (e) {
      _bookings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> createBooking(int motorId, String startDate, String endDate) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await ApiClient.post('/bookings', {
        'motorId': motorId,
        'startDate': startDate,
        'endDate': endDate,
      });
      return response['bookingId'];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadDp(int bookingId, String base64Image) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await ApiClient.put('/bookings/$bookingId/dp', {
        'dp_bukti': base64Image,
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
