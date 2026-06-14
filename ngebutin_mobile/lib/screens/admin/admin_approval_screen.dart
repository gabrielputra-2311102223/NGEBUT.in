import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';

class AdminApprovalScreen extends StatelessWidget {
  const AdminApprovalScreen({Key? key}) : super(key: key);

  String _formatCurrency(dynamic amount) {
    try {
      final int v = (amount as num).toInt();
      return 'Rp ${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    } catch (_) {
      return 'Rp 0';
    }
  }

  String _formatDate(dynamic val) {
    if (val == null) return '-';
    return val.toString().split('T')[0];
  }

  void _showDpImage(BuildContext context, String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti DP belum diupload')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: base64String.startsWith('data:image')
              ? Image.memory(base64Decode(base64String.split(',')[1]))
              : Image.network(base64String),
        ),
      ),
    );
  }

  void _processApproval(BuildContext context, BookingProvider provider, int bookingId, String action) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approve' ? 'Setujui Booking?' : 'Tolak Booking?'),
        content: Text(action == 'approve'
            ? 'Booking #$bookingId akan disetujui dan motor dinyatakan aktif disewa.'
            : 'Booking #$bookingId akan ditolak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action == 'approve' ? 'Setujui' : 'Tolak',
                style: TextStyle(color: action == 'approve' ? Colors.green : Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await provider.approveBooking(bookingId, action);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approve' ? '✅ Booking disetujui!' : '❌ Booking ditolak'),
          backgroundColor: action == 'approve' ? Colors.green : Colors.red,
        ));
        provider.fetchAllBookings();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // Admin juga bisa selesaikan sewa (returning → done)
  void _processReturn(BuildContext context, BookingProvider provider, int bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selesaikan Sewa?'),
        content: const Text('Motor sudah dikembalikan dan dicek kondisinya?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Selesai', style: TextStyle(color: Colors.green))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await provider.updateBookingStatus(bookingId, 'done');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Sewa selesai!'), backgroundColor: Colors.green));
        provider.fetchAllBookings();
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));

        // Perlu approval: status='confirm' dengan dp_uploaded/verifikasi
        final needApproval = provider.bookings.where((b) {
          final s = b['status']?.toString() ?? '';
          final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
          return s == 'confirm' && (sp == 'dp_uploaded' || sp == 'verifikasi');
        }).toList();

        // Perlu dicek pengembalian: status='returning'
        final needReturn = provider.bookings.where((b) {
          final s = b['status']?.toString() ?? '';
          return s == 'returning';
        }).toList();

        final allPending = [...needApproval, ...needReturn];

        if (allPending.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Tidak ada yang perlu diproses', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.fetchAllBookings,
          color: const Color(0xFFCC0000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (needApproval.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(width: 4, height: 20, color: const Color(0xFF0369A1)),
                      const SizedBox(width: 8),
                      Text('Verifikasi DP (${needApproval.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                ...needApproval.map((b) => _buildApprovalCard(context, provider, b)),
                const SizedBox(height: 16),
              ],
              if (needReturn.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(width: 4, height: 20, color: const Color(0xFF6B21A8)),
                      const SizedBox(width: 8),
                      Text('Pengembalian Motor (${needReturn.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                ...needReturn.map((b) => _buildReturnCard(context, provider, b)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovalCard(BuildContext context, BookingProvider provider, Map b) {
    final bookingId = (b['id'] as num).toInt();
    final userName = b['userName'] ?? 'User #${b['userId'] ?? b['user_id']}';
    final motorName = b['motorName'] ?? 'Motor #${b['motorId'] ?? b['motor_id']}';
    final dpBukti = b['dpBukti'] ?? b['dp_bukti'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #$bookingId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFBAE6FD), borderRadius: BorderRadius.circular(12)),
                child: const Text('VERIFIKASI DP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.person, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.motorcycle, size: 16, color: Color(0xFFCC0000)),
            const SizedBox(width: 6),
            Expanded(child: Text(motorName, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('${_formatDate(b['startDate'] ?? b['tgl_mulai'])} → ${_formatDate(b['endDate'] ?? b['tgl_selesai'])}'),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total:', style: TextStyle(color: Colors.grey)),
            Text(_formatCurrency(b['totalHarga'] ?? b['total_harga'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          if (dpBukti != null && dpBukti.toString().isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _showDpImage(context, dpBukti.toString()),
              icon: const Icon(Icons.image, color: Color(0xFF0369A1)),
              label: const Text('Lihat Bukti Transfer DP', style: TextStyle(color: Color(0xFF0369A1))),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0369A1))),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _processApproval(context, provider, bookingId, 'reject'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFEE2E2), foregroundColor: Colors.red, elevation: 0),
                  child: const Text('TOLAK'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _processApproval(context, provider, bookingId, 'approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDCFCE7), foregroundColor: const Color(0xFF166534), elevation: 0),
                  child: const Text('TERIMA'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(BuildContext context, BookingProvider provider, Map b) {
    final bookingId = (b['id'] as num).toInt();
    final userName = b['userName'] ?? 'User #${b['userId'] ?? b['user_id']}';
    final motorName = b['motorName'] ?? 'Motor #${b['motorId'] ?? b['motor_id']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Order #$bookingId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE9D5FF), borderRadius: BorderRadius.circular(12)),
              child: const Text('DIKEMBALIKAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8))),
            ),
          ]),
          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.person, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.motorcycle, size: 16, color: Color(0xFFCC0000)),
            const SizedBox(width: 6),
            Expanded(child: Text(motorName, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _processReturn(context, provider, bookingId),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('SELESAIKAN SEWA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF166534), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
