import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';

class AdminPembayaranScreen extends StatefulWidget {
  const AdminPembayaranScreen({Key? key}) : super(key: key);

  @override
  State<AdminPembayaranScreen> createState() => _AdminPembayaranScreenState();
}

class _AdminPembayaranScreenState extends State<AdminPembayaranScreen> {
  String _currentFilter = 'confirmed'; // confirmed, returning, completed

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _updateStatus(BuildContext context, BookingProvider provider, int bookingId, String newStatus) async {
    try {
      await provider.updateBookingStatus(bookingId, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status pembayaran diperbarui')));
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

        List<dynamic> filteredBookings = [];
        if (_currentFilter == 'confirmed') {
          filteredBookings = provider.bookings.where((b) => b['status'] == 'confirmed').toList();
        } else if (_currentFilter == 'returning') {
          filteredBookings = provider.bookings.where((b) => b['status'] == 'returning').toList();
        } else {
          filteredBookings = provider.bookings.where((b) => b['status'] == 'completed').toList();
        }

        return Column(
          children: [
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
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final b = filteredBookings[index];
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
                                      decoration: BoxDecoration(
                                        color: _currentFilter == 'paid' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF08A),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        b['status'].toString().toUpperCase(), 
                                        style: TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.bold, 
                                          color: _currentFilter == 'paid' ? const Color(0xFF166534) : const Color(0xFF854D0E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Text('Motor ID: ${b['motorId'] ?? b['motor_id']}'),
                                const SizedBox(height: 8),
                                Text('Total Harga: ${_formatCurrency((b['totalHarga'] ?? b['total_harga'] ?? 0) is num ? (b['totalHarga'] ?? b['total_harga'] ?? 0).toInt() : int.tryParse((b['totalHarga'] ?? b['total_harga'] ?? 0).toString()) ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                if (_currentFilter == 'booked') ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _updateStatus(context, provider, b['id'], 'paid'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                                      child: const Text('KONFIRMASI PELUNASAN'),
                                    ),
                                  ),
                                ] else if (_currentFilter == 'returning') ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _updateStatus(context, provider, b['id'], 'finished'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                                      child: const Text('SELESAIKAN PENYEWAAN'),
                                    ),
                                  ),
                                ]
                              ],
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
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
