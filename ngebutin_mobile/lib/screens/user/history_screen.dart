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
        final userId = (user['id'] as num).toInt();
        Provider.of<BookingProvider>(context, listen: false).fetchMyBookings(userId);
      }
    });
  }

  String _formatCurrency(dynamic amount) {
    try {
      final int val = (amount as num).toInt();
      return 'Rp ${val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (_) {
      return 'Rp 0';
    }
  }

  String _formatDate(dynamic val) {
    if (val == null) return '-';
    try {
      return val.toString().split('T')[0];
    } catch (_) {
      return val.toString();
    }
  }

  Widget _buildStatusBadge(String? status, String? statusPembayaran) {
    final s = status ?? '';
    final sp = statusPembayaran ?? '';

    Color bgColor;
    Color textColor;
    String text;

    if (s == 'confirm' && sp == 'menunggu_dp') {
      bgColor = const Color(0xFFFEF08A); textColor = const Color(0xFF854D0E); text = 'MENUNGGU DP';
    } else if (s == 'confirm' && (sp == 'dp_uploaded' || sp == 'verifikasi')) {
      bgColor = const Color(0xFFBAE6FD); textColor = const Color(0xFF0369A1); text = 'VERIFIKASI DP';
    } else if (s == 'booked' && sp == 'dp_lunas') {
      bgColor = const Color(0xFFBBF7D0); textColor = const Color(0xFF166534); text = 'AKTIF SEWA';
    } else if (s == 'returning') {
      bgColor = const Color(0xFFE9D5FF); textColor = const Color(0xFF6B21A8); text = 'DIKEMBALIKAN';
    } else if (s == 'done') {
      bgColor = const Color(0xFFE5E7EB); textColor = const Color(0xFF374151); text = 'SELESAI';
    } else if (s == 'rejected') {
      bgColor = const Color(0xFFFEE2E2); textColor = const Color(0xFFCC0000); text = 'DITOLAK';
    } else if (s == 'cancelled') {
      bgColor = const Color(0xFFF3F4F6); textColor = const Color(0xFF6B7280); text = 'DIBATALKAN';
    } else {
      bgColor = Colors.grey.shade200; textColor = Colors.grey.shade800; text = s.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Riwayat & Sewa Aktif', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
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
                final userId = (user['id'] as num).toInt();
                await provider.fetchMyBookings(userId);
              }
            },
            color: const Color(0xFFCC0000),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.bookings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final b = provider.bookings[index];
                final status = b['status']?.toString() ?? '';
                final statusPembayaran = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
                final motorName = (b['motorName'] ?? b['motor_name'] ?? 'Motor').toString();
                final bookingId = (b['id'] as num).toInt();
                final totalHarga = b['totalHarga'] ?? b['total_harga'] ?? 0;
                final dpAmount = b['dpAmount'] ?? b['dp_amount'] ?? ((totalHarga as num).toInt() ~/ 2);

                // Apakah perlu upload DP
                final needsDp = status == 'confirm' && statusPembayaran == 'menunggu_dp';
                // Apakah bisa kembalikan motor
                final canReturn = status == 'booked' && statusPembayaran == 'dp_lunas';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: needsDp
                          ? const Color(0xFFCC0000).withOpacity(0.3)
                          : canReturn
                              ? Colors.green.withOpacity(0.3)
                              : Colors.grey.shade200,
                      width: needsDp || canReturn ? 1.5 : 1,
                    ),
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
                          Text('Order #$bookingId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                          _buildStatusBadge(status, statusPembayaran),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.motorcycle, color: Color(0xFFCC0000), size: 18),
                          const SizedBox(width: 8),
                          Text(motorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFFCC0000), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_formatDate(b['startDate'] ?? b['tgl_mulai'])} s/d ${_formatDate(b['endDate'] ?? b['tgl_selesai'])}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Biaya', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text(_formatCurrency(totalHarga), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('DP (50%)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text(_formatCurrency(dpAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFFCC0000))),
                            ],
                          ),
                        ],
                      ),
                      // Tombol Upload DP
                      if (needsDp) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DpUploadScreen(
                                    bookingId: bookingId,
                                    dpAmount: (dpAmount as num).toInt(),
                                  ),
                                ),
                              ).then((_) {
                                // Refresh after returning
                                final user = Provider.of<AuthProvider>(context, listen: false).user;
                                if (user != null && context.mounted) {
                                  provider.fetchMyBookings((user['id'] as num).toInt());
                                }
                              });
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
                      ]
                      // Tombol Kembalikan Motor
                      else if (canReturn) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Kembalikan Motor'),
                                  content: const Text('Apakah Anda yakin sudah selesai menyewa dan ingin mengembalikan motor ini?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Ya, Kembalikan', style: TextStyle(color: Colors.green)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                try {
                                  await Provider.of<BookingProvider>(context, listen: false)
                                      .updateBookingStatus(bookingId, 'returning');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('✅ Permintaan pengembalian dikirim! Admin akan memproses.'), backgroundColor: Colors.green),
                                    );
                                    final user = Provider.of<AuthProvider>(context, listen: false).user;
                                    if (user != null) {
                                      provider.fetchMyBookings((user['id'] as num).toInt());
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Gagal memproses: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.undo),
                            label: const Text('KEMBALIKAN MOTOR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF166534),
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
