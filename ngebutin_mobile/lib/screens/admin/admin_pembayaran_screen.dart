import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/booking_provider.dart';

class AdminPembayaranScreen extends StatefulWidget {
  const AdminPembayaranScreen({Key? key}) : super(key: key);

  @override
  State<AdminPembayaranScreen> createState() => _AdminPembayaranScreenState();
}

class _AdminPembayaranScreenState extends State<AdminPembayaranScreen> {
  String _currentFilter = 'confirmed'; // confirmed, returning, completed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<BookingProvider>(context, listen: false).fetchAllBookings();
      }
    });
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _updateStatus(BuildContext context, BookingProvider provider, int bookingId, String newStatus) async {
    try {
      await provider.updateBookingStatus(bookingId, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Status berhasil diperbarui'), backgroundColor: Colors.green));
        provider.fetchAllBookings();
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _openKwitansi(BuildContext context, dynamic bookingId) async {
    final url = Uri.parse('https://ngebut-in.vercel.app/api/kwitansi/$bookingId');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal buka kwitansi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));

        List<dynamic> filteredBookings = [];
        if (_currentFilter == 'confirmed') {
          // Toleransi: 'confirmed' = sudah approve DP, 'booked' = legacy
          filteredBookings = provider.bookings.where((b) {
            final s = (b['status'] ?? '').toString();
            return s == 'confirmed' || s == 'booked';
          }).toList();
        } else if (_currentFilter == 'returning') {
          filteredBookings = provider.bookings.where((b) =>
              (b['status'] ?? '').toString() == 'returning').toList();
        } else {
          filteredBookings = provider.bookings.where((b) =>
              (b['status'] ?? '').toString() == 'completed').toList();
        }

        return Column(
          children: [
            // Tab Filter
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(child: _buildTab('Aktif Sewa', 'confirmed')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTab('Proses Kembali', 'returning')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTab('Selesai', 'completed')),
                ],
              ),
            ),

            Expanded(
              child: filteredBookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text('Tidak ada data', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: provider.fetchAllBookings,
                      color: const Color(0xFFCC0000),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredBookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final b = filteredBookings[index];
                          final bookingId = b['id'];
                          final motorName = b['motorName'] ?? b['motor_name'] ?? 'Motor';
                          final userName = b['userName'] ?? b['user_name'] ?? 'User';
                          final total = (b['totalHarga'] ?? b['total_harga'] ?? 0);
                          final dp = (b['dpAmount'] ?? b['dp_amount'] ?? 0);
                          final totalInt = total is num ? total.toInt() : int.tryParse(total.toString()) ?? 0;
                          final dpInt = dp is num ? dp.toInt() : int.tryParse(dp.toString()) ?? 0;
                          final pelunasan = totalInt - dpInt;
                          final startDate = (b['startDate'] ?? b['tgl_mulai'] ?? '-').toString().split('T')[0];
                          final endDate = (b['endDate'] ?? b['tgl_selesai'] ?? '-').toString().split('T')[0];

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('#${bookingId.toString().padLeft(6, '0')}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace', color: Color(0xFF6B7280))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _currentFilter == 'completed' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF9C3),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _currentFilter == 'completed' ? '✅ SELESAI' :
                                          _currentFilter == 'returning' ? '↩️ KEMBALI' : '🏍️ AKTIF',
                                          style: TextStyle(
                                            fontSize: 10, fontWeight: FontWeight.bold,
                                            color: _currentFilter == 'completed' ? const Color(0xFF166534) : const Color(0xFF854D0E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Motor & User info
                                  Row(
                                    children: [
                                      const Icon(Icons.motorcycle, color: Color(0xFFCC0000), size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(motorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person, color: Colors.grey, size: 16),
                                      const SizedBox(width: 6),
                                      Text(userName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month, color: Colors.grey, size: 16),
                                      const SizedBox(width: 6),
                                      Text('$startDate  →  $endDate', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                  const Divider(height: 20),

                                  // Payment info
                                  Row(
                                    children: [
                                      Expanded(child: _payCell('Total', _formatCurrency(totalInt), const Color(0xFFCC0000))),
                                      Expanded(child: _payCell('DP', _formatCurrency(dpInt), const Color(0xFF059669))),
                                      Expanded(child: _payCell('Pelunasan', _formatCurrency(pelunasan), const Color(0xFF1E40AF))),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Action buttons
                                  if (_currentFilter == 'confirmed') ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await provider.confirmReturn(bookingId);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('✅ Motor ditandai dikembalikan'), backgroundColor: Colors.green));
                                              provider.fetchAllBookings();
                                            }
                                          } catch (e) {
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                          }
                                        },
                                        icon: const Icon(Icons.undo, size: 16),
                                        label: const Text('TANDAI KEMBALI'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ] else if (_currentFilter == 'returning') ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await provider.approvePelunasan(bookingId);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('✅ Pelunasan dikonfirmasi, sewa selesai!'), backgroundColor: Colors.green));
                                              provider.fetchAllBookings();
                                            }
                                          } catch (e) {
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                          }
                                        },
                                        icon: const Icon(Icons.check_circle, size: 16),
                                        label: const Text('KONFIRMASI PELUNASAN & SELESAI'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ] else if (_currentFilter == 'completed') ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _openKwitansi(context, bookingId),
                                        icon: const Icon(Icons.receipt_long, size: 16),
                                        label: const Text('LIHAT KWITANSI'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFCC0000),
                                          side: const BorderSide(color: Color(0xFFCC0000)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _payCell(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildTab(String label, String filterValue) {
    final isSelected = _currentFilter == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = filterValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCC0000) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
