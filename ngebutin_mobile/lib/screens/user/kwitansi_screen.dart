import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class KwitansiScreen extends StatelessWidget {
  final Map<String, dynamic> booking;

  const KwitansiScreen({Key? key, required this.booking}) : super(key: key);

  String _formatRupiah(dynamic val) {
    final n = (val is num) ? val.toInt() : int.tryParse(val.toString()) ?? 0;
    final s = n.toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return 'Rp ${result.toString()}';
  }

  int _calcDays() {
    try {
      final start = DateTime.parse((booking['startDate'] ?? booking['tgl_mulai'] ?? '').toString());
      final end = DateTime.parse((booking['endDate'] ?? booking['tgl_selesai'] ?? '').toString());
      return end.difference(start).inDays.abs() + 1;
    } catch (_) { return 1; }
  }

  @override
  Widget build(BuildContext context) {
    final id = booking['id']?.toString() ?? '';
    final userName = (booking['userName'] ?? booking['user_name'] ?? 'Penyewa').toString();
    final motorName = (booking['motorName'] ?? booking['motor_name'] ?? 'Motor').toString();
    final startDate = (booking['startDate'] ?? booking['tgl_mulai'] ?? '-').toString();
    final endDate = (booking['endDate'] ?? booking['tgl_selesai'] ?? '-').toString();
    final total = (booking['totalHarga'] ?? booking['total_harga'] ?? 0) as num;
    final dp = (booking['dpAmount'] ?? booking['dp_amount'] ?? (total / 2)).toInt();
    final pelunasan = total.toInt() - dp;
    final days = _calcDays();
    final harga = days > 0 ? (total / days).toInt() : total.toInt();
    final now = DateTime.now();
    final tanggalCetak = '${now.day}/${now.month}/${now.year}';
    final noTransaksi = id.isNotEmpty ? '#${id.substring(id.length >= 6 ? id.length - 6 : 0)}' : '#-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Kwitansi Sewa', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFFCC0000)),
            onPressed: () => _copyToClipboard(context, userName, motorName, startDate, endDate, days, harga, total, dp, pelunasan, noTransaksi, tanggalCetak),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kwitansi Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFCC0000),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.motorcycle, color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        const Text('NGEBUT.IN', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        const Text('KWITANSI SEWA MOTOR', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text(noTransaksi, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _kwitansiRow('Penyewa', userName),
                        _kwitansiRow('Motor', motorName),
                        const Divider(height: 24),
                        _kwitansiRow('Tanggal Sewa', startDate),
                        _kwitansiRow('Tanggal Kembali', endDate),
                        _kwitansiRow('Durasi', '$days Hari'),
                        _kwitansiRow('Harga/Hari', _formatRupiah(harga)),
                        const Divider(height: 24),
                        _kwitansiRow('Total Sewa', _formatRupiah(total), isBold: true, valueColor: const Color(0xFFCC0000)),
                        _kwitansiRow('DP Dibayar', _formatRupiah(dp), valueColor: const Color(0xFF059669)),
                        _kwitansiRow('Pelunasan', _formatRupiah(pelunasan), valueColor: const Color(0xFF1E40AF)),
                        const Divider(height: 24),
                        _kwitansiRow('Tanggal Cetak', tanggalCetak),

                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
                              SizedBox(width: 8),
                              Text('LUNAS', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                    ),
                    child: const Text(
                      'Terima kasih telah menggunakan layanan Ngebut.in\nDokumen ini merupakan bukti transaksi yang sah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _copyToClipboard(context, userName, motorName, startDate, endDate, days, harga, total, dp, pelunasan, noTransaksi, tanggalCetak),
                icon: const Icon(Icons.copy),
                label: const Text('Salin Kwitansi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kwitansiRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              fontSize: isBold ? 16 : 13,
              color: valueColor ?? const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext ctx, String userName, String motorName, String startDate, String endDate, int days, int harga, num total, int dp, int pelunasan, String noTrx, String tanggal) {
    final text = '''
==============================
🏍️ KWITANSI NGEBUT.IN
==============================
No. Transaksi : $noTrx
Penyewa       : $userName
Motor         : $motorName
Tgl Sewa      : $startDate
Tgl Kembali   : $endDate
Durasi        : $days Hari
Harga/Hari    : ${_formatRupiah(harga)}
------------------------------
Total Sewa    : ${_formatRupiah(total)}
DP Dibayar    : ${_formatRupiah(dp)}
Pelunasan     : ${_formatRupiah(pelunasan)}
------------------------------
Status        : ✅ LUNAS
Tgl Cetak     : $tanggal
==============================
Terima kasih menggunakan Ngebut.in!
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('✅ Kwitansi disalin ke clipboard!'), backgroundColor: Colors.green));
  }
}
