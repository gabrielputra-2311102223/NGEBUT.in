import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import 'dp_upload_screen.dart';

class BookingSayaScreen extends StatefulWidget {
  const BookingSayaScreen({Key? key}) : super(key: key);

  @override
  State<BookingSayaScreen> createState() => _BookingSayaScreenState();
}

class _BookingSayaScreenState extends State<BookingSayaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      final uid = (user['id'] as num).toInt();
      await Provider.of<BookingProvider>(context, listen: false).fetchMyBookings(uid);
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

  Color _statusColor(String status, String sp) {
    if (status == 'confirm' && sp == 'menunggu_dp') return const Color(0xFFFEF08A);
    if (status == 'confirm' && sp == 'dp_uploaded') return const Color(0xFFBAE6FD);
    if (status == 'booked') return const Color(0xFFBBF7D0);
    if (status == 'returning') return const Color(0xFFE9D5FF);
    return Colors.grey.shade200;
  }

  Color _statusTextColor(String status, String sp) {
    if (status == 'confirm' && sp == 'menunggu_dp') return const Color(0xFF854D0E);
    if (status == 'confirm' && sp == 'dp_uploaded') return const Color(0xFF0369A1);
    if (status == 'booked') return const Color(0xFF166534);
    if (status == 'returning') return const Color(0xFF6B21A8);
    return Colors.grey.shade700;
  }

  String _statusText(String status, String sp) {
    if (status == 'confirm' && sp == 'menunggu_dp') return '⏳ Menunggu Upload DP';
    if (status == 'confirm' && sp == 'dp_uploaded') return '🔍 Verifikasi DP';
    if (status == 'booked' && sp == 'dp_lunas') return '🏍️ Sedang Aktif Sewa';
    if (status == 'returning') return '↩️ Menunggu Dicek';
    return status.toUpperCase();
  }

  IconData _statusIcon(String status, String sp) {
    if (status == 'confirm' && sp == 'menunggu_dp') return Icons.upload_file;
    if (status == 'confirm' && sp == 'dp_uploaded') return Icons.hourglass_top;
    if (status == 'booked') return Icons.motorcycle;
    if (status == 'returning') return Icons.undo;
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Booking Saya', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
          }

          // Booking aktif: confirm (menunggu_dp / dp_uploaded) + booked (dp_lunas) + returning
          final activeBookings = provider.bookings.where((b) {
            final s = b['status']?.toString() ?? '';
            final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
            return (s == 'confirm') || (s == 'booked' && sp == 'dp_lunas') || s == 'returning';
          }).toList();

          if (activeBookings.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFFCC0000),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('Belum ada sewa aktif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                        const SizedBox(height: 8),
                        const Text('Pesan motor dari halaman Katalog', style: TextStyle(color: Colors.grey)),
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
              itemCount: activeBookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final b = activeBookings[index];
                final status = b['status']?.toString() ?? '';
                final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
                final bookingId = (b['id'] as num).toInt();
                final motorName = (b['motorName'] ?? b['motor_name'] ?? 'Motor').toString();
                final totalHarga = b['totalHarga'] ?? b['total_harga'] ?? 0;
                final dpAmount = b['dpAmount'] ?? b['dp_amount'] ?? ((totalHarga as num).toInt() ~/ 2);

                final needsDP = status == 'confirm' && sp == 'menunggu_dp';
                final waitVerif = status == 'confirm' && (sp == 'dp_uploaded' || sp == 'verifikasi');
                final canReturn = status == 'booked' && sp == 'dp_lunas';
                final isReturning = status == 'returning';

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _statusColor(status, sp),
                      width: 2,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      // Status Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _statusColor(status, sp),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
                        ),
                        child: Row(
                          children: [
                            Icon(_statusIcon(status, sp), size: 18, color: _statusTextColor(status, sp)),
                            const SizedBox(width: 8),
                            Text(_statusText(status, sp), style: TextStyle(fontWeight: FontWeight.bold, color: _statusTextColor(status, sp))),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order #$bookingId', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(
                                  motorName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Color(0xFFCC0000)),
                                const SizedBox(width: 8),
                                Text(
                                  '${_formatDate(b['startDate'] ?? b['tgl_mulai'])} → ${_formatDate(b['endDate'] ?? b['tgl_selesai'])}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(_formatCurrency(totalHarga), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('DP 50%', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(_formatCurrency(dpAmount), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFCC0000))),
                                  ],
                                ),
                              ],
                            ),

                            // Action Buttons
                            if (needsDP) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => DpUploadScreen(bookingId: bookingId, dpAmount: (dpAmount as num).toInt()),
                                    )).then((_) { if (mounted) _refresh(); });
                                  },
                                  icon: const Icon(Icons.upload),
                                  label: const Text('UPLOAD BUKTI DP SEKARANG'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFCC0000), foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                  ),
                                ),
                              ),
                            ] else if (waitVerif) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFF0369A1), size: 18),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('Admin sedang memverifikasi bukti DP Anda. Harap tunggu.', style: TextStyle(color: Color(0xFF0369A1), fontSize: 13))),
                                  ],
                                ),
                              ),
                            ] else if (canReturn) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Kembalikan Motor'),
                                        content: const Text('Yakin sudah selesai menyewa dan ingin mengembalikan motor?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Kembalikan', style: TextStyle(color: Colors.green))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && context.mounted) {
                                      try {
                                        await Provider.of<BookingProvider>(context, listen: false).updateBookingStatus(bookingId, 'returning');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Motor dikembalikan! Admin akan memproses.'), backgroundColor: Colors.green));
                                          _refresh();
                                        }
                                      } catch (e) {
                                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.undo),
                                  label: const Text('KEMBALIKAN MOTOR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF166534), foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                  ),
                                ),
                              ),
                            ] else if (isReturning) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(10)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.undo, color: Color(0xFF6B21A8), size: 18),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('Motor dalam proses pengecekan oleh admin.', style: TextStyle(color: Color(0xFF6B21A8), fontSize: 13))),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
