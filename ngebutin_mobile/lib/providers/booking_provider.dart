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
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      // Gunakan endpoint dedicated per user untuk efisiensi
      final response = await ApiClient.get('/bookings/my/$userId');
      final newBookings = List<dynamic>.from(response);
      newBookings.sort((a, b) =>
          _safeParseDate(b['createdAt']).compareTo(_safeParseDate(a['createdAt'])));
      _bookings = newBookings;
    } catch (e) {
      // Fallback: fetch all dan filter
      try {
        final all = await ApiClient.get('/bookings');
        final uidStr = userId.toString();
        _bookings = List<dynamic>.from(all).where((b) {
          final bId = (b['userId'] ?? b['user_id']);
          return bId?.toString() == uidStr;
        }).toList();
        _bookings.sort((a, b) =>
            _safeParseDate(b['createdAt']).compareTo(_safeParseDate(a['createdAt'])));
      } catch (_) {
        // Jangan kosongkan data lama saat error
      }
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

  Future<Map<String, dynamic>> createBooking(
      int userId, int motorId, String startDate, String endDate, int totalHarga) async {
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
      final id = (response['bookingId'] ?? response['id'] ?? 0) as num;
      final dp = (response['dpAmount'] ?? response['dp_amount'] ?? 0) as num;
      final pelunasan = (response['pelunasanAmount'] ?? 0) as num;
      return {
        'bookingId': id.toInt(),
        'dpAmount': dp.toInt(),
        'pelunasanAmount': pelunasan.toInt(),
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upload bukti DP
  Future<void> uploadDp(int bookingId, String base64Image) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/upload-dp', {
        'dp_bukti': base64Image,
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upload bukti pelunasan
  Future<void> uploadPelunasan(int bookingId, String base64Image) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/upload-pelunasan', {
        'bukti_pelunasan': base64Image,
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin: Approve DP
  Future<void> approveDP(int bookingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/approve-dp', {});
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin: Reject DP
  Future<void> rejectDP(int bookingId, {String? alasan}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/reject-dp', {
        'catatan_admin': alasan ?? 'Bukti DP tidak valid',
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin: Konfirmasi motor dikembalikan
  Future<void> confirmReturn(int bookingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/return', {});
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin: Approve pelunasan
  Future<void> approvePelunasan(int bookingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/approve-pelunasan', {});
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin: Selesaikan dengan pelunasan tunai
  Future<void> completeCash(int bookingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/complete-cash', {});
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// User/Admin: Cancel booking
  Future<void> cancelBooking(int bookingId, {String? alasan}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.put('/bookings/$bookingId/cancel', {
        'catatan_admin': alasan ?? 'Dibatalkan',
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Legacy compat
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
    if (action == 'approve') {
      await approveDP(bookingId);
    } else {
      await rejectDP(bookingId);
    }
  }
}
