import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';

class AdminApprovalScreen extends StatelessWidget {
  const AdminApprovalScreen({Key? key}) : super(key: key);

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _showDpImage(BuildContext context, String base64String) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: base64String.startsWith('data:image') 
              ? Image.memory(base64Decode(base64String.split(',')[1])) 
              : Image.network(base64String),
        ),
      ),
    );
  }

  void _processApproval(BuildContext context, BookingProvider provider, int bookingId, String action) async {
    try {
      await provider.approveBooking(bookingId, action);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'approve' ? 'Booking disetujui' : 'Booking ditolak')));
        provider.fetchAllBookings();
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));

        final pendingBookings = provider.bookings.where((b) => 
            b['status'] == 'pending' && 
            (b['statusPembayaran'] == 'dp_uploaded' || b['status_pembayaran'] == 'dp_uploaded' || b['statusPembayaran'] == 'verifikasi' || b['status_pembayaran'] == 'verifikasi')
        ).toList();

        if (pendingBookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Tidak ada booking yang menunggu approval', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.fetchAllBookings,
          color: const Color(0xFFCC0000),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pendingBookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final b = pendingBookings[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order #${b['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFBAE6FD), borderRadius: BorderRadius.circular(12)),
                          child: const Text('VERIFIKASI DP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('User ID: ${b['userId'] ?? b['user_id']}'),
                    Text('Motor ID: ${b['motorId'] ?? b['motor_id']}'),
                    const SizedBox(height: 8),
                    Text('Total Harga: ${_formatCurrency(((b['totalHarga'] ?? b['total_harga'] ?? 0) as num).toInt())}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (b['dpBukti'] != null || b['dp_bukti'] != null)
                      OutlinedButton.icon(
                        onPressed: () => _showDpImage(context, b['dpBukti'] ?? b['dp_bukti']),
                        icon: const Icon(Icons.image),
                        label: const Text('Lihat Bukti Transfer DP'),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _processApproval(context, provider, b['id'], 'reject'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFEE2E2), foregroundColor: Colors.red),
                            child: const Text('TOLAK'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _processApproval(context, provider, b['id'], 'approve'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDCFCE7), foregroundColor: Colors.green),
                            child: const Text('TERIMA'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
