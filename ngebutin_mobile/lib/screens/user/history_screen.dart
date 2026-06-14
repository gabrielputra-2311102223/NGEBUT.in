import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import 'kwitansi_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      await Provider.of<BookingProvider>(context, listen: false)
          .fetchMyBookings((user['id'] as num).toInt());
    }
  }

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

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case 'done':
        bg = const Color(0xFFDCFCE7); fg = const Color(0xFF166534);
        text = 'SELESAI'; icon = Icons.check_circle;
        break;
      case 'cancelled':
        bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280);
        text = 'DIBATALKAN'; icon = Icons.cancel;
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2); fg = const Color(0xFFCC0000);
        text = 'DITOLAK'; icon = Icons.block;
        break;
      case 'returning':
        bg = const Color(0xFFE9D5FF); fg = const Color(0xFF6B21A8);
        text = 'DIKEMBALIKAN'; icon = Icons.undo;
        break;
      default:
        bg = Colors.grey.shade200; fg = Colors.grey.shade700;
        text = status.toUpperCase(); icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Riwayat Pesanan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
          }

          // Riwayat: HANYA yang sudah selesai/batal/ditolak
          final history = provider.bookings.where((b) {
            final s = b['status']?.toString() ?? '';
            return ['done', 'cancelled', 'rejected', 'returning'].contains(s);
          }).toList();

          if (history.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFFCC0000),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('Belum ada riwayat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                        const SizedBox(height: 8),
                        const Text('Riwayat muncul setelah sewa selesai atau dibatalkan', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFFCC0000),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final b = history[index];
                final status = b['status']?.toString() ?? '';
                final motorName = (b['motorName'] ?? b['motor_name'] ?? 'Motor').toString();
                final bookingId = (b['id'] as num).toInt();
                final totalHarga = b['totalHarga'] ?? b['total_harga'] ?? 0;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order #$bookingId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.motorcycle, color: Color(0xFFCC0000), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(motorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.grey, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatDate(b['startDate'] ?? b['tgl_mulai'])} s/d ${_formatDate(b['endDate'] ?? b['tgl_selesai'])}',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Biaya', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          Text(
                            _formatCurrency(totalHarga),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                          ),
                        ],
                      ),
                      if (status == 'rejected') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFFCC0000), size: 16),
                              SizedBox(width: 6),
                              Expanded(child: Text('Bukti DP Anda tidak valid. Silakan hubungi admin.', style: TextStyle(color: Color(0xFFCC0000), fontSize: 12))),
                            ],
                          ),
                        ),
                      ],
                      if (status == 'done') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KwitansiScreen(booking: b))),
                            icon: const Icon(Icons.receipt_long, size: 16, color: Color(0xFF059669)),
                            label: const Text('Lihat Kwitansi', style: TextStyle(color: Color(0xFF059669), fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF059669)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
