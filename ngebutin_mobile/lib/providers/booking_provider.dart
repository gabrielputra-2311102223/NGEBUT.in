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
      _bookings = allBookings.where((b) => b['userId'] == userId || b['user_id'] == userId).toList();
      // Sort by newest
      _bookings.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
    } catch (e) {
      _bookings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllBookings() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.get('/bookings');
      _bookings = List<dynamic>.from(response);
      _bookings.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
    } catch (e) {
      _bookings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> createBooking(int userId, int motorId, String startDate, String endDate, int totalHarga) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await ApiClient.post('/bookings', {
        'user_id': userId,
        'motor_id': motorId,
        'tgl_mulai': startDate,
        'tgl_selesai': endDate,
        'total_harga': totalHarga,
      });
      return response['bookingId'] ?? response['id'] ?? 0;
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

  Future<void> updateBookingStatus(int bookingId, String status) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/status', {'status': status});
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveBooking(int bookingId, String action) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.post('/bookings/$bookingId/approve-dp', {'action': action});
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
