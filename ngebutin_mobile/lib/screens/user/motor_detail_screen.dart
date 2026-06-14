import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/motor.dart';
import '../../providers/booking_provider.dart';
import '../../providers/auth_provider.dart';
import 'dp_upload_screen.dart';

class MotorDetailScreen extends StatefulWidget {
  final Motor motor;

  const MotorDetailScreen({Key? key, required this.motor}) : super(key: key);

  @override
  _MotorDetailScreenState createState() => _MotorDetailScreenState();
}

class _MotorDetailScreenState extends State<MotorDetailScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  Widget _buildImage(String base64String) {
    try {
      if (base64String.startsWith('data:image')) {
        final splitted = base64String.split(',');
        return Image.memory(
          base64Decode(splitted[1]),
          fit: BoxFit.cover,
        );
      }
      return Image.network(
        base64String,
        fit: BoxFit.cover,
      );
    } catch (e) {
      return const Icon(Icons.motorcycle, size: 100, color: Colors.grey);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFCC0000), 
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  int get _totalDays {
    if (_startDate == null || _endDate == null) return 0;
    final diff = _endDate!.difference(_startDate!).inDays;
    return diff == 0 ? 1 : diff + 1; // Minimum 1 hari
  }

  int get _totalPrice {
    return _totalDays * widget.motor.harga;
  }
  
  int get _dpAmount {
    return (_totalPrice / 2).round();
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Future<void> _processBooking() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal sewa terlebih dahulu!'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Cek status motor — service = tidak bisa sama sekali
    if (widget.motor.status == 'service') {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(children: [Icon(Icons.build, color: Colors.orange), SizedBox(width: 8), Text('Motor Dalam Perbaikan')]),
          content: const Text('Motor ini sedang dalam perbaikan (servis) dan tidak dapat dipesan saat ini. Silakan pilih motor lain.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti'))],
        ),
      );
      return;
    }

    // Cek status motor — booked = hanya boleh mulai besok atau lebih
    if (widget.motor.status == 'booked') {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      if (_startDate!.isBefore(tomorrow)) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [Icon(Icons.motorcycle, color: Color(0xFFCC0000)), SizedBox(width: 8), Text('Motor Sedang Disewa')]),
            content: const Text('Motor ini sedang aktif disewa. Anda bisa memesan untuk tanggal mendatang setelah motor dikembalikan.\n\nSilakan pilih tanggal mulai mulai besok atau lebih.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ganti Tanggal'))],
          ),
        );
        return;
      }
    }

    try {
      final String startStr = "${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}";
      final String endStr = "${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}";

      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final userId = user != null ? user['id'] : 0;

      final provider = Provider.of<BookingProvider>(context, listen: false);
      final bookingId = await provider.createBooking(userId, widget.motor.id, startStr, endStr, _totalPrice);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DpUploadScreen(
              bookingId: bookingId,
              dpAmount: _dpAmount,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Tampilkan pesan ramah, bukan raw exception
        final msg = e.toString().contains('Exception:')
            ? e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')
            : 'Gagal memproses pemesanan. Coba lagi atau hubungi admin.';
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [Icon(Icons.error_outline, color: Color(0xFFCC0000)), SizedBox(width: 8), Text('Pemesanan Gagal')]),
            content: Text(msg),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final motor = widget.motor;
    final bookingProvider = Provider.of<BookingProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(motor.nama),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 250,
                    color: Colors.white,
                    child: _buildImage(motor.gambar),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                motor.nama,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Status badge dari status aktual motor
                            Builder(builder: (_) {
                              final isAvailable = motor.status == 'available';
                              final isService = motor.status == 'service';
                              final Color bgColor = isAvailable
                                  ? const Color(0xFFDCFCE7)
                                  : isService ? const Color(0xFFFFF3CD) : const Color(0xFFFEE2E2);
                              final Color txtColor = isAvailable
                                  ? const Color(0xFF166534)
                                  : isService ? const Color(0xFF856404) : const Color(0xFF991B1B);
                              final String label = isAvailable ? 'TERSEDIA' : isService ? 'SERVIS' : 'DISEWA';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                                child: Text(label, style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              );
                            }),
                          ],
                        ),
                        // Banner peringatan jika motor sedang disewa
                        if (motor.status == 'booked') ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.info_outline, color: Color(0xFF92400E), size: 18),
                              SizedBox(width: 8),
                              Expanded(child: Text('Motor sedang disewa. Anda bisa memesan untuk tanggal mendatang setelah motor kembali.', style: TextStyle(color: Color(0xFF92400E), fontSize: 12))),
                            ]),
                          ),
                        ],
                        if (motor.status == 'service') ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCC0000).withOpacity(0.3)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.build, color: Color(0xFF991B1B), size: 18),
                              SizedBox(width: 8),
                              Expanded(child: Text('Motor sedang dalam perbaikan dan tidak dapat dipesan saat ini.', style: TextStyle(color: Color(0xFF991B1B), fontSize: 12))),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '${motor.formattedHarga} /hari',
                          style: const TextStyle(fontSize: 20, color: Color(0xFFCC0000), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.settings, size: 20, color: Colors.grey),
                                    const SizedBox(height: 4),
                                    Text(motor.kategori.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.thumb_up, size: 20, color: Colors.grey),
                                    const SizedBox(height: 4),
                                    const Text('Prima', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.local_gas_station, size: 20, color: Colors.grey),
                                    const SizedBox(height: 4),
                                    const Text('Bensin', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Deskripsi',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          motor.deskripsi,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Tanggal Sewa',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectDateRange(context),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Color(0xFFCC0000)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _startDate == null 
                                      ? 'Pilih Tanggal Sewa' 
                                      : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                                    style: TextStyle(
                                      color: _startDate == null ? Colors.grey : Colors.black,
                                      fontWeight: _startDate == null ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        if (_startDate != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFE4E6)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Hari'),
                                    Text('$_totalDays Hari', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Harga'),
                                    Text(_formatCurrency(_totalPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('DP yang harus dibayar (50%)', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(_formatCurrency(_dpAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFCC0000), fontSize: 16)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              // Nonaktifkan tombol jika motor servis atau loading
              onPressed: (bookingProvider.isLoading || motor.status == 'service')
                  ? null
                  : _processBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: motor.status == 'service' ? Colors.grey : const Color(0xFFCC0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: bookingProvider.isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    motor.status == 'service'
                        ? 'TIDAK TERSEDIA - DALAM SERVIS'
                        : motor.status == 'booked'
                            ? 'PESAN UNTUK TANGGAL MENDATANG'
                            : 'LANJUT PEMBAYARAN DP',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
