import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class KwitansiScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  const KwitansiScreen({Key? key, required this.booking}) : super(key: key);

  String _fmt(dynamic val) {
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
      final s = DateTime.parse((booking['startDate'] ?? booking['tgl_mulai'] ?? '').toString());
      final e = DateTime.parse((booking['endDate'] ?? booking['tgl_selesai'] ?? '').toString());
      return e.difference(s).inDays.abs() + 1;
    } catch (_) { return 1; }
  }

  /// Generate logo as base64 from assets
  Future<String> _logoBase64() async {
    try {
      final data = await rootBundle.load('assets/logo.png');
      return base64Encode(data.buffer.asUint8List());
    } catch (_) { return ''; }
  }

  Future<void> _printKwitansi(BuildContext context) async {
    final id = booking['id']?.toString() ?? '';
    if (id.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID Booking tidak ditemukan'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final url = Uri.parse('https://ngebut-in.vercel.app/api/kwitansi/$id');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka kwitansi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareWhatsApp(BuildContext context, String text) async {
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      _copyText(context, text);
    }
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Kwitansi disalin ke clipboard!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = booking['id']?.toString() ?? '';
    final userName = (booking['userName'] ?? booking['user_name'] ?? 'Penyewa').toString();
    final motorName = (booking['motorName'] ?? booking['motor_name'] ?? 'Motor').toString();
    final startDate = (booking['startDate'] ?? booking['tgl_mulai'] ?? '-').toString();
    final endDate = (booking['endDate'] ?? booking['tgl_selesai'] ?? '-').toString();
    final int total = ((booking['totalHarga'] ?? booking['total_harga'] ?? 0) as num).toInt();
    final int days = _calcDays();
    final int dp = ((booking['dpAmount'] ?? booking['dp_amount'] ?? (total ~/ 2)) as num).toInt();
    final int pelunasan = total - dp;
    final int harga = days > 0 ? total ~/ days : total;
    final now = DateTime.now();
    final tglCetak = '${now.day}/${now.month}/${now.year}';
    final noTrx = id.isNotEmpty ? '#${id.substring(id.length >= 6 ? id.length - 6 : 0)}' : '#-';

    final kwitansiText = '''==============================
🏍️ KWITANSI NGEBUT.IN
==============================
No. Transaksi : $noTrx
Penyewa       : $userName
Motor         : $motorName
Tgl Sewa      : $startDate
Tgl Kembali   : $endDate
Durasi        : $days Hari
Harga/Hari    : ${_fmt(harga)}
------------------------------
Total Sewa    : ${_fmt(total)}
DP Dibayar    : ${_fmt(dp)}
Pelunasan     : ${_fmt(pelunasan)}
------------------------------
Status        : ✅ LUNAS
Tgl Cetak     : $tglCetak
==============================
Terima kasih menggunakan Ngebut.in!''';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Kwitansi Sewa', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFFCC0000)),
            tooltip: 'Cetak / Simpan PDF',
            onPressed: () => _printKwitansi(context),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF25D366)),
            tooltip: 'Kirim WhatsApp',
            onPressed: () => _shareWhatsApp(context, kwitansiText),
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
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8))],
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
                        Image.asset('assets/logo.png', height: 52, color: Colors.white, colorBlendMode: BlendMode.srcATop),
                        const SizedBox(height: 6),
                        const Text('NGEBUT.IN', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        const Text('KWITANSI SEWA MOTOR', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(8)),
                          child: Text(noTrx, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _row('Penyewa', userName),
                        _row('Motor', motorName),
                        const Divider(height: 20),
                        _row('Tanggal Sewa', startDate),
                        _row('Tanggal Kembali', endDate),
                        _row('Durasi', '$days Hari'),
                        _row('Harga/Hari', _fmt(harga)),
                        const Divider(height: 20),
                        _row('Total Sewa', _fmt(total), isBold: true, valueColor: const Color(0xFFCC0000)),
                        _row('DP Dibayar (50%)', _fmt(dp), valueColor: const Color(0xFF059669)),
                        _row('Pelunasan (50%)', _fmt(pelunasan), valueColor: const Color(0xFF1E40AF)),
                        const Divider(height: 20),
                        _row('Tanggal Cetak', tglCetak),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF059669), size: 22),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                    ),
                    child: const Text(
                      'Terima kasih telah menggunakan layanan Ngebut.in\nDokumen ini merupakan bukti transaksi yang sah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Print Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _printKwitansi(context),
                icon: const Icon(Icons.print),
                label: const Text('🖨️  Cetak / Simpan PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Share WhatsApp button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _shareWhatsApp(context, kwitansiText),
                icon: const Icon(Icons.send),
                label: const Text('Kirim via WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyText(context, kwitansiText),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Salin Teks'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFCC0000),
                  side: const BorderSide(color: Color(0xFFCC0000)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Tombol Cetak membuka kwitansi di browser.\nGunakan "Print" di browser untuk menyimpan PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: isBold ? 15 : 13, color: valueColor ?? const Color(0xFF1A1A1A))),
        ],
      ),
    );
  }
}
