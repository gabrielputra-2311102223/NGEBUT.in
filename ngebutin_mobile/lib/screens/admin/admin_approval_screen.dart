import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';

class AdminApprovalScreen extends StatelessWidget {
  const AdminApprovalScreen({super.key});

  String _fmt(dynamic amount) {
    try {
      final int v = (amount as num).toInt();
      return 'Rp ${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    } catch (_) { return 'Rp 0'; }
  }

  String _date(dynamic val) {
    if (val == null) return '-';
    return val.toString().split('T')[0];
  }

  void _showImage(BuildContext context, String? b64, String title) {
    if (b64 == null || b64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title belum diupload')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            InteractiveViewer(
              child: b64.startsWith('data:image')
                  ? Image.memory(base64Decode(b64.split(',')[1]))
                  : Image.network(b64),
            ),
          ],
        ),
      ),
    );
  }

  // DP Approval
  void _approveDP(BuildContext context, BookingProvider bp, int id) async {
    final ok = await _confirm(context, 'Terima DP?', 'Booking #$id akan disetujui. Motor aktif disewa.', confirmColor: Colors.green);
    if (ok != true) return;
    try {
      await bp.approveDP(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ DP diverifikasi!'), backgroundColor: Colors.green));
        bp.fetchAllBookings();
      }
    } catch (e) { _showError(context, e); }
  }

  void _rejectDP(BuildContext context, BookingProvider bp, int id) async {
    final alasan = await _prompt(context, 'Alasan Penolakan', 'Masukkan alasan menolak bukti DP:');
    if (alasan == null) return;
    try {
      await bp.rejectDP(id, alasan: alasan.isEmpty ? 'Bukti DP tidak valid' : alasan);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Booking ditolak'), backgroundColor: Colors.red));
        bp.fetchAllBookings();
      }
    } catch (e) { _showError(context, e); }
  }

  // Confirm motor returned
  void _confirmReturn(BuildContext context, BookingProvider bp, int id) async {
    final ok = await _confirm(context, 'Motor Dikembalikan?', 'Konfirmasi motor untuk booking #$id sudah dikembalikan. User perlu membayar pelunasan.', confirmColor: const Color(0xFF7C3AED));
    if (ok != true) return;
    try {
      await bp.confirmReturn(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('↩️ Motor dikonfirmasi kembali!'), backgroundColor: Color(0xFF7C3AED)));
        bp.fetchAllBookings();
      }
    } catch (e) { _showError(context, e); }
  }

  // Approve pelunasan
  void _approvePelunasan(BuildContext context, BookingProvider bp, int id) async {
    final ok = await _confirm(context, 'Konfirmasi Pelunasan?', 'Booking #$id akan diselesaikan. Motor kembali tersedia.', confirmColor: Colors.green);
    if (ok != true) return;
    try {
      await bp.approvePelunasan(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pelunasan dikonfirmasi! Selesai.'), backgroundColor: Colors.green));
        bp.fetchAllBookings();
      }
    } catch (e) { _showError(context, e); }
  }

  void _completeCash(BuildContext context, BookingProvider bp, int id) async {
    final ok = await _confirm(context, 'Lunas Tunai?', 'Konfirmasi pelunasan tunai di tempat untuk booking #$id.', confirmColor: Colors.green);
    if (ok != true) return;
    try {
      await bp.completeCash(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pelunasan tunai dikonfirmasi!'), backgroundColor: Colors.green));
        bp.fetchAllBookings();
      }
    } catch (e) { _showError(context, e); }
  }

  Future<bool?> _confirm(BuildContext ctx, String title, String msg, {Color confirmColor = Colors.red}) {
    return showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }

  Future<String?> _prompt(BuildContext ctx, String title, String hint) async {
    String input = '';
    return showDialog<String>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          onChanged: (v) => input = v,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, input),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext ctx, Object e) {
    if (ctx.mounted) {
      showDialog(context: ctx, builder: (_) => AlertDialog(
        title: const Text('Terjadi Kesalahan'),
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, bp, _) {
        if (bp.isLoading && bp.bookings.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
        }

        // Section 1: Verifikasi DP — pending + dp_uploaded
        final needDP = bp.bookings.where((b) {
          final s = (b['status'] ?? '').toString();
          final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
          return s == 'pending' && (sp == 'dp_uploaded' || sp == 'verifikasi');
        }).toList();

        // Section 2: Sewa Aktif — confirmed
        final active = bp.bookings.where((b) => (b['status'] ?? '') == 'confirmed').toList();

        // Section 3: Proses Pengembalian — returning
        final returning = bp.bookings.where((b) => (b['status'] ?? '') == 'returning').toList();

        if (needDP.isEmpty && active.isEmpty && returning.isEmpty) {
          return RefreshIndicator(
            onRefresh: bp.fetchAllBookings,
            color: const Color(0xFFCC0000),
            child: ListView(
              children: [
                SizedBox(
                  height: 400,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Semua beres! Tidak ada yang perlu diproses.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                          textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: bp.fetchAllBookings,
          color: const Color(0xFFCC0000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Section: Verifikasi DP
              if (needDP.isNotEmpty) ...[
                _sectionHeader('🔍 Verifikasi DP', needDP.length, const Color(0xFF0369A1), const Color(0xFFBAE6FD)),
                ...needDP.map((b) => _buildDPCard(context, bp, Map<String, dynamic>.from(b))),
                const SizedBox(height: 12),
              ],

              // Section: Konfirmasi Pengembalian
              if (active.isNotEmpty) ...[
                _sectionHeader('🏍️ Motor Aktif Disewa', active.length, const Color(0xFF059669), const Color(0xFFD1FAE5)),
                ...active.map((b) => _buildActiveCard(context, bp, Map<String, dynamic>.from(b))),
                const SizedBox(height: 12),
              ],

              // Section: Pelunasan
              if (returning.isNotEmpty) ...[
                _sectionHeader('↩️ Proses Pelunasan', returning.length, const Color(0xFF6B21A8), const Color(0xFFE9D5FF)),
                ...returning.map((b) => _buildPelunasanCard(context, bp, Map<String, dynamic>.from(b))),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, int count, Color color, Color bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('$title ($count)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ]),
    );
  }

  Widget _buildDPCard(BuildContext ctx, BookingProvider bp, Map<String, dynamic> b) {
    final id = (b['id'] as num).toInt();
    final dpBukti = b['dpBukti'] ?? b['dp_bukti'];
    final total = b['totalHarga'] ?? b['total_harga'] ?? 0;
    final dp = b['dpAmount'] ?? b['dp_amount'] ?? 0;

    return _card(
      borderColor: const Color(0xFFBAE6FD),
      header: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('#${id.toString().padLeft(6, '0').substring(id.toString().length > 6 ? id.toString().length - 6 : 0)}',
          style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade500, fontSize: 12)),
        _badge('🔍 VERIFIKASI DP', const Color(0xFFBAE6FD), const Color(0xFF0369A1)),
      ]),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.person, b['userName'] ?? 'User'),
          const SizedBox(height: 4),
          _infoRow(Icons.motorcycle, b['motorName'] ?? 'Motor', color: const Color(0xFFCC0000)),
          const SizedBox(height: 4),
          _infoRow(Icons.calendar_today, '${_date(b['startDate'] ?? b['tgl_mulai'])} → ${_date(b['endDate'] ?? b['tgl_selesai'])}'),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total:', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text(_fmt(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('DP (50%):', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text(_fmt(dp), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF059669))),
          ]),
          const SizedBox(height: 10),
          if (dpBukti != null && dpBukti.toString().isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _showImage(ctx, dpBukti.toString(), 'Bukti DP'),
              icon: const Icon(Icons.image_search, color: Color(0xFF0369A1)),
              label: const Text('Lihat Bukti Transfer DP', style: TextStyle(color: Color(0xFF0369A1))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0369A1)),
                minimumSize: const Size(double.infinity, 38),
              ),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () => _rejectDP(ctx, bp, id),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFEE2E2), foregroundColor: Colors.red, elevation: 0),
              child: const Text('❌ TOLAK'),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => _approveDP(ctx, bp, id),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDCFCE7), foregroundColor: const Color(0xFF166534), elevation: 0),
              child: const Text('✅ TERIMA'),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildActiveCard(BuildContext ctx, BookingProvider bp, Map<String, dynamic> b) {
    final id = (b['id'] as num).toInt();
    final total = b['totalHarga'] ?? 0;
    final pelunasan = b['pelunasanAmount'] ?? ((total as num) - ((b['dpAmount'] ?? 0) as num));

    return _card(
      borderColor: const Color(0xFFD1FAE5),
      header: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('#${id.toString().padLeft(6, '0').substring(id.toString().length > 6 ? id.toString().length - 6 : 0)}',
          style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade500, fontSize: 12)),
        _badge('🏍️ AKTIF SEWA', const Color(0xFFD1FAE5), const Color(0xFF059669)),
      ]),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.person, b['userName'] ?? 'User'),
          const SizedBox(height: 4),
          _infoRow(Icons.motorcycle, b['motorName'] ?? 'Motor', color: const Color(0xFFCC0000)),
          const SizedBox(height: 4),
          _infoRow(Icons.calendar_today, '${_date(b['startDate'] ?? b['tgl_mulai'])} → ${_date(b['endDate'] ?? b['tgl_selesai'])}'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Sisa Pelunasan:', style: TextStyle(color: Color(0xFF6B21A8), fontSize: 13)),
              Text(_fmt(pelunasan), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7C3AED))),
            ]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmReturn(ctx, bp, id),
              icon: const Icon(Icons.undo),
              label: const Text('Konfirmasi Motor Kembali'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPelunasanCard(BuildContext ctx, BookingProvider bp, Map<String, dynamic> b) {
    final id = (b['id'] as num).toInt();
    final total = b['totalHarga'] ?? 0;
    final dp = b['dpAmount'] ?? 0;
    final pelunasan = b['pelunasanAmount'] ?? ((total as num) - (dp as num));
    final sp = (b['statusPembayaran'] ?? '').toString();
    final buktiPelunasan = b['buktiPelunasan'] ?? b['bukti_pelunasan'];

    return _card(
      borderColor: const Color(0xFFE9D5FF),
      header: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('#${id.toString().padLeft(6, '0').substring(id.toString().length > 6 ? id.toString().length - 6 : 0)}',
          style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade500, fontSize: 12)),
        _badge(sp == 'pelunasan_uploaded' ? '🔍 VERIFIKASI PELUNASAN' : '⏳ MENUNGGU PELUNASAN',
          const Color(0xFFE9D5FF), const Color(0xFF6B21A8)),
      ]),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.person, b['userName'] ?? 'User'),
          const SizedBox(height: 4),
          _infoRow(Icons.motorcycle, b['motorName'] ?? 'Motor', color: const Color(0xFFCC0000)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Sisa Pelunasan:', style: TextStyle(color: Color(0xFFB45309), fontSize: 13)),
              Text(_fmt(pelunasan), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFCC0000))),
            ]),
          ),
          if (buktiPelunasan != null && buktiPelunasan.toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showImage(ctx, buktiPelunasan.toString(), 'Bukti Pelunasan'),
              icon: const Icon(Icons.image_search, color: Color(0xFF6B21A8)),
              label: const Text('Lihat Bukti Pelunasan', style: TextStyle(color: Color(0xFF6B21A8))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6B21A8)),
                minimumSize: const Size(double.infinity, 38),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: () => _completeCash(ctx, bp, id),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD1FAE5), foregroundColor: const Color(0xFF059669), elevation: 0),
              child: const Text('💵 Tunai'),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: sp == 'pelunasan_uploaded' ? () => _approvePelunasan(ctx, bp, id) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: sp == 'pelunasan_uploaded' ? const Color(0xFFDCFCE7) : Colors.grey.shade200,
                foregroundColor: sp == 'pelunasan_uploaded' ? const Color(0xFF166534) : Colors.grey,
                elevation: 0),
              child: Text(sp == 'pelunasan_uploaded' ? '✅ Konfirmasi' : '⏳ Menunggu'),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _card({required Color borderColor, required Widget header, required Widget body}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        header,
        const Divider(height: 18),
        body,
      ]),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color color = Colors.grey}) {
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(color: color == Colors.grey ? Colors.grey.shade700 : color, fontWeight: FontWeight.w600, fontSize: 13))),
    ]);
  }
}
