import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import 'dp_upload_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<BookingProvider>(context, listen: false).fetchMyBookings(user['id']);
      }
    });
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Widget _buildStatusBadge(String status, String statusPembayaran) {
    Color bgColor = Colors.grey.shade200;
    Color textColor = Colors.grey.shade800;
    String text = status.toUpperCase();

    if (status == 'pending' && statusPembayaran == 'menunggu_dp') {
      bgColor = const Color(0xFFFEF08A);
      textColor = const Color(0xFF854D0E);
      text = 'MENUNGGU DP';
    } else if (status == 'pending' && statusPembayaran == 'dp_uploaded') {
      bgColor = const Color(0xFFBAE6FD);
      textColor = const Color(0xFF0369A1);
      text = 'VERIFIKASI DP';
    } else if (status == 'paid' || status == 'booked') {
      bgColor = const Color(0xFFBBF7D0);
      textColor = const Color(0xFF166534);
      text = 'DISEWA';
    } else if (status == 'finished') {
      bgColor = const Color(0xFFE5E7EB);
      textColor = const Color(0xFF374151);
      text = 'SELESAI';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
          }

          if (provider.bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Belum ada riwayat pesanan', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final user = Provider.of<AuthProvider>(context, listen: false).user;
              if (user != null) {
                await provider.fetchMyBookings(user['id']);
              }
            },
            color: const Color(0xFFCC0000),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final b = provider.bookings[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order #${b['id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          _buildStatusBadge(b['status'], b['statusPembayaran']),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFFCC0000), size: 20),
                          const SizedBox(width: 8),
                          Text('${b['startDate'].toString().split('T')[0]} s/d ${b['endDate'].toString().split('T')[0]}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Biaya', style: TextStyle(color: Colors.grey)),
                          Text(_formatCurrency(b['totalHarga']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      if (b['status'] == 'pending' && b['statusPembayaran'] == 'menunggu_dp') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DpUploadScreen(
                                    bookingId: b['id'],
                                    dpAmount: (b['totalHarga'] / 2).round(),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.upload),
                            label: const Text('UPLOAD BUKTI DP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFCC0000),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
