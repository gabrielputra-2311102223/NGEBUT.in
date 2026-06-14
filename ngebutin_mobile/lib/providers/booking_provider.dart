import 'package:flutter/material.dart';
import '../core/api_client.dart';

class BookingProvider with ChangeNotifier {
  bool _isLoading = false;
  List<dynamic> _bookings = [];

  bool get isLoading => _isLoading;
  List<dynamic> get bookings => _bookings;

  // Safe date parse helper
  static DateTime _safeParseDate(dynamic val) {
    try {
      if (val == null) return DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.parse(val.toString());
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<void> fetchMyBookings(int userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.get('/bookings');
      final List<dynamic> allBookings = List<dynamic>.from(response);
      _bookings = allBookings
          .where((b) => b['userId'] == userId || b['user_id'] == userId)
          .toList();
      _bookings.sort((a, b) =>
          _safeParseDate(b['createdAt']).compareTo(_safeParseDate(a['createdAt'])));
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
      _bookings.sort((a, b) =>
          _safeParseDate(b['createdAt']).compareTo(_safeParseDate(a['createdAt'])));
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
      // API returns { bookingId, dpAmount, message }
      final id = response['bookingId'] ?? response['id'] ?? 0;
      return (id as num).toInt();
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
      if (action == 'approve') {
        // Approve DP → PUT /bookings/:id/approve-dp
        await ApiClient.put('/bookings/$bookingId/approve-dp', {});
      } else {
        // Reject → PUT /bookings/:id/status with status=rejected
        await ApiClient.put('/bookings/$bookingId/status', {'status': 'rejected'});
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
