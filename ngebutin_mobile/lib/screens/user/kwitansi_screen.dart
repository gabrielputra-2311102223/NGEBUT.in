import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

  Future<void> _printKwitansi(BuildContext context) async {
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
    final tanggalCetak = '${now.day}/${now.month}/${now.year}';
    final noTransaksi = id.isNotEmpty ? '#${id.substring(id.length >= 6 ? id.length - 6 : 0)}' : '#-';

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFCC0000)),
              child: pw.Column(children: [
                pw.Text('🏍️ NGEBUT.IN', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('KWITANSI SEWA MOTOR', style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Text('No. Transaksi: $noTransaksi', style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
            pw.SizedBox(height: 16),
            // Detail
            _pdfRow('Penyewa', userName),
            _pdfRow('Motor', motorName),
            pw.Divider(),
            _pdfRow('Tanggal Sewa', startDate),
            _pdfRow('Tanggal Kembali', endDate),
            _pdfRow('Durasi', '$days Hari'),
            _pdfRow('Harga/Hari', _formatRupiah(harga)),
            pw.Divider(),
            _pdfRowBold('Total Sewa', _formatRupiah(total)),
            _pdfRow('DP Dibayar (50%)', _formatRupiah(dp)),
            _pdfRow('Pelunasan (50%)', _formatRupiah(pelunasan)),
            pw.Divider(),
            _pdfRow('Tanggal Cetak', tanggalCetak),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDCFCE7)),
              child: pw.Center(
                child: pw.Text('✅ LUNAS', style: pw.TextStyle(color: PdfColor.fromInt(0xFF166534), fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'Terima kasih telah menggunakan layanan Ngebut.in',
                style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Kwitansi_NgebutIN_$noTransaksi.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mencetak: $e'), backgroundColor: Colors.red));
      }
    }
  }

  pw.Widget _pdfRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 11)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );

  pw.Widget _pdfRowBold(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 12)),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFFCC0000))),
      ],
    ),
  );

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
    final tanggalCetak = '${now.day}/${now.month}/${now.year}';
    final noTransaksi = id.isNotEmpty ? '#${id.substring(id.length >= 6 ? id.length - 6 : 0)}' : '#-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Kwitansi Sewa', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFFCC0000)),
            tooltip: 'Cetak PDF',
            onPressed: () => _printKwitansi(context),
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
                        const Icon(Icons.motorcycle, color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        const Text('NGEBUT.IN', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        const Text('KWITANSI SEWA MOTOR', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(8)),
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

            const SizedBox(height: 12),

            // Copy Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyToClipboard(context, userName, motorName, startDate, endDate, days, harga, total, dp, pelunasan, noTransaksi, tanggalCetak),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Salin Teks Kwitansi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFCC0000),
                  side: const BorderSide(color: Color(0xFFCC0000)),
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

  void _copyToClipboard(BuildContext ctx, String userName, String motorName, String startDate, String endDate, int days, int harga, int total, int dp, int pelunasan, String noTrx, String tanggal) {
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
