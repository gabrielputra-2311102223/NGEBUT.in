import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import 'kwitansi_screen.dart';

class BookingSayaScreen extends StatefulWidget {
  const BookingSayaScreen({Key? key}) : super(key: key);

  @override
  State<BookingSayaScreen> createState() => _BookingSayaScreenState();
}

class _BookingSayaScreenState extends State<BookingSayaScreen> {
  String _filter = 'active'; // active, all, pending, completed

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

  String _formatRupiah(dynamic v) {
    try {
      final int n = (v as num).toInt();
      return 'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    } catch (_) { return 'Rp 0'; }
  }

  String _formatDate(dynamic v) {
    if (v == null) return '-';
    try {
      final d = DateTime.parse(v.toString());
      const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return v.toString().split('T')[0]; }
  }

  int _calcDays(dynamic start, dynamic end) {
    try {
      final s = DateTime.parse(start.toString());
      final e = DateTime.parse(end.toString());
      return e.difference(s).inDays.abs() + 1;
    } catch (_) { return 1; }
  }

  // Status helpers
  String _statusText(Map b) {
    final st = b['status'] ?? '';
    final sp = b['statusPembayaran'] ?? b['status_pembayaran'] ?? '';
    if (st == 'pending' && sp == 'menunggu_dp') return '⏳ Upload DP';
    if (st == 'pending' && sp == 'dp_uploaded') return '🔍 Verifikasi DP';
    if (st == 'confirmed') return '🏍️ Aktif Sewa';
    if (st == 'returning' && sp == 'menunggu_pelunasan') return '↩️ Upload Pelunasan';
    if (st == 'returning' && sp == 'pelunasan_uploaded') return '🔍 Verifikasi Pelunasan';
    if (st == 'completed') return '✅ Selesai';
    if (st == 'rejected') return '❌ DP Ditolak';
    if (st == 'cancelled') return '🚫 Dibatalkan';
    return st.toString().toUpperCase();
  }

  Color _statusColor(Map b) {
    final st = b['status'] ?? '';
    if (st == 'pending') return const Color(0xFFFEF9C3);
    if (st == 'confirmed') return const Color(0xFFDCFCE7);
    if (st == 'returning') return const Color(0xFFEDE9FE);
    if (st == 'completed') return const Color(0xFFDCFCE7);
    if (st == 'rejected') return const Color(0xFFFEE2E2);
    if (st == 'cancelled') return const Color(0xFFF3F4F6);
    return Colors.grey.shade100;
  }

  Color _statusTextColor(Map b) {
    final st = b['status'] ?? '';
    if (st == 'pending') return const Color(0xFF92400E);
    if (st == 'confirmed') return const Color(0xFF166534);
    if (st == 'returning') return const Color(0xFF5B21B6);
    if (st == 'completed') return const Color(0xFF166534);
    if (st == 'rejected') return const Color(0xFF991B1B);
    if (st == 'cancelled') return const Color(0xFF374151);
    return Colors.grey.shade700;
  }

  // Timeline widget
  Widget _buildTimeline(Map b) {
    final st = b['status'] ?? '';
    final sp = b['statusPembayaran'] ?? b['status_pembayaran'] ?? '';

    int currentStep = 0;
    if (st == 'completed') currentStep = 5;
    else if (st == 'returning' && sp == 'pelunasan_uploaded') currentStep = 4;
    else if (st == 'returning') currentStep = 3;
    else if (st == 'confirmed') currentStep = 2;
    else if (st == 'pending' && sp == 'dp_uploaded') currentStep = 1;

    final steps = [
      {'icon': Icons.event_note, 'label': 'Booking'},
      {'icon': Icons.upload_file, 'label': 'Upload DP'},
      {'icon': Icons.motorcycle, 'label': 'Aktif'},
      {'icon': Icons.undo, 'label': 'Kembali'},
      {'icon': Icons.payments, 'label': 'Pelunasan'},
      {'icon': Icons.check_circle, 'label': 'Selesai'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final isDone = i < currentStep;
          final isActive = i == currentStep;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0) Expanded(
                      child: Container(height: 2, color: i <= currentStep ? const Color(0xFFCC0000) : Colors.grey.shade200),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? const Color(0xFF059669) : isActive ? const Color(0xFFCC0000) : Colors.grey.shade200,
                        border: Border.all(
                          color: isDone ? const Color(0xFF059669) : isActive ? const Color(0xFFCC0000) : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isDone ? Icons.check : step['icon'] as IconData,
                        size: 14,
                        color: isDone || isActive ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                    if (i < steps.length - 1) Expanded(
                      child: Container(height: 2, color: i < currentStep ? const Color(0xFFCC0000) : Colors.grey.shade200),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step['label'] as String,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDone ? const Color(0xFF059669) : isActive ? const Color(0xFFCC0000) : Colors.grey.shade400,
                    fontWeight: isDone || isActive ? FontWeight.w700 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _getFiltered(List<dynamic> all) {
    List<Map<String, dynamic>> cast(List<dynamic> lst) =>
        lst.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (_filter == 'active') return cast(all.where((b) => ['pending', 'confirmed', 'returning'].contains(b['status'])).toList());
    if (_filter == 'pending') return cast(all.where((b) => b['status'] == 'pending').toList());
    if (_filter == 'completed') return cast(all.where((b) => b['status'] == 'completed').toList());
    return cast(all);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Sewa Saya', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFCC0000)),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Consumer<BookingProvider>(
        builder: (ctx, bp, _) {
          if (bp.isLoading && bp.bookings.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
          }

          final filtered = _getFiltered(bp.bookings);

          return RefreshIndicator(
            color: const Color(0xFFCC0000),
            onRefresh: _refresh,
            child: Column(
              children: [
                // Filter pills
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterPill('active', '⚡ Aktif'),
                        const SizedBox(width: 8),
                        _filterPill('pending', '⏳ Menunggu'),
                        const SizedBox(width: 8),
                        _filterPill('completed', '✅ Selesai'),
                        const SizedBox(width: 8),
                        _filterPill('all', '📋 Semua'),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.motorcycle_outlined, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('Belum ada booking', style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text('Mulai sewa motor favoritmu sekarang!', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _buildBookingCard(filtered[i] as Map<String, dynamic>, bp),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildMotorImage(String gambar) {
    const w = 80.0;
    const h = 60.0;
    if (gambar.isEmpty) return _motorPlaceholder();
    try {
      if (gambar.startsWith('data:image')) {
        final parts = gambar.split(',');
        if (parts.length > 1) {
          return Image.memory(
            base64Decode(parts[1]),
            width: w, height: h, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _motorPlaceholder(),
          );
        }
      }
      // Network URL
      return Image.network(
        gambar, width: w, height: h, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _motorPlaceholder(),
      );
    } catch (_) { return _motorPlaceholder(); }
  }

  Widget _motorPlaceholder() {
    return Container(
      width: 80, height: 60,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.motorcycle, color: Colors.grey.shade400, size: 32),
    );
  }

  Widget _filterPill(String key, String label) {
    final isActive = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFCC0000) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isActive ? const Color(0xFFCC0000) : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          color: isActive ? Colors.white : Colors.grey.shade700,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        )),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b, BookingProvider bp) {
    final st = b['status'] ?? '';
    final sp = b['statusPembayaran'] ?? b['status_pembayaran'] ?? '';
    final total = ((b['totalHarga'] ?? b['total_harga'] ?? 0) as num);
    final dp = ((b['dpAmount'] ?? b['dp_amount'] ?? 0) as num);
    final pelunasan = ((b['pelunasanAmount'] ?? (total - dp)) as num);
    final motor = b['motorName'] ?? b['motor_name'] ?? 'Motor';
    final bookingId = (b['id'] as num).toInt();
    final days = _calcDays(b['startDate'] ?? b['tgl_mulai'], b['endDate'] ?? b['tgl_selesai']);

    final gambar = b['motorGambar'] ?? b['motor_gambar'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${bookingId.toString().padLeft(6, '0').substring(bookingId.toString().length > 6 ? bookingId.toString().length - 6 : 0)}',
                  style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade500, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(b),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_statusText(b), style: TextStyle(color: _statusTextColor(b), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          // Motor info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Motor image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMotorImage(gambar),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(motor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                      const SizedBox(height: 4),
                      Text('${b['motorKategori'] ?? ''} • ${_formatRupiah(b['motorHarga'] ?? 0)}/hari',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dates & Payment
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _metaItem('Mulai', _formatDate(b['startDate'] ?? b['tgl_mulai']))),
                  Expanded(child: _metaItem('Kembali', _formatDate(b['endDate'] ?? b['tgl_selesai']))),
                  Expanded(child: _metaItem('Durasi', '$days hari')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _metaItem('Total', _formatRupiah(total), valueColor: const Color(0xFFCC0000))),
                  Expanded(child: _metaItem('DP (50%)', _formatRupiah(dp), valueColor: const Color(0xFF059669))),
                  Expanded(child: _metaItem('Pelunasan', _formatRupiah(pelunasan), valueColor: const Color(0xFF7C3AED))),
                ]),
              ],
            ),
          ),

          // Timeline
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTimeline(b),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: _buildActions(b, bp, bookingId, dp.toInt(), pelunasan.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _metaItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor ?? const Color(0xFF1F2937))),
      ],
    );
  }

  Widget _motorPlaceholder() {
    return Container(
      width: 80, height: 60,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.motorcycle, color: Colors.grey, size: 32),
    );
  }

  Widget _buildActions(Map<String, dynamic> b, BookingProvider bp, int bookingId, int dpAmount, int pelunasanAmount) {
    final st = b['status'] ?? '';
    final sp = b['statusPembayaran'] ?? b['status_pembayaran'] ?? '';

    if (st == 'pending' && sp == 'menunggu_dp') {
      return _actionBtn('Upload Bukti DP', Icons.upload_file, const Color(0xFFCC0000),
        () => _showUploadModal(bookingId, 'dp', dpAmount, bp));
    }
    if (st == 'pending' && sp == 'dp_uploaded') {
      return _infoBox('🔍 Menunggu verifikasi DP oleh admin...', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8));
    }
    if (st == 'confirmed') {
      return _infoBox('🏍️ Motor sedang aktif disewa. Kembalikan tepat waktu!', const Color(0xFFF0FDF4), const Color(0xFF166534));
    }
    if (st == 'returning' && sp == 'menunggu_pelunasan') {
      return Column(children: [
        _actionBtn('Upload Bukti Pelunasan', Icons.payments, const Color(0xFF7C3AED),
          () => _showUploadModal(bookingId, 'pelunasan', pelunasanAmount, bp)),
        const SizedBox(height: 6),
        _infoBox('💡 Atau bayar tunai langsung ke admin di tempat.', const Color(0xFFFEFCE8), const Color(0xFF92400E)),
      ]);
    }
    if (st == 'returning' && sp == 'pelunasan_uploaded') {
      return _infoBox('🔍 Bukti pelunasan terkirim. Menunggu konfirmasi admin...', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8));
    }
    if (st == 'completed') {
      return Row(children: [
        Expanded(child: _actionBtn('Lihat Kwitansi', Icons.receipt_long, const Color(0xFF059669),
          () => _showKwitansi(b))),
      ]);
    }
    if (st == 'rejected') {
      final alasan = b['catatanAdmin'] ?? 'Bukti DP tidak valid';
      return _infoBox('❌ DP ditolak: $alasan', const Color(0xFFFEF2F2), const Color(0xFF991B1B));
    }
    if (st == 'cancelled') {
      return _infoBox('🚫 Booking ini dibatalkan.', const Color(0xFFF3F4F6), const Color(0xFF374151));
    }
    return const SizedBox.shrink();
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(double.infinity, 44),
      ),
    );
  }

  Widget _infoBox(String msg, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(child: Text(msg, style: TextStyle(color: textColor, fontSize: 12))),
      ]),
    );
  }

  void _showUploadModal(int bookingId, String type, int amount, BookingProvider bp) {
    File? selectedFile;
    bool isUploading = false;

    final title = type == 'dp' ? 'Upload Bukti DP' : 'Upload Bukti Pelunasan';
    final amountLabel = type == 'dp' ? 'Jumlah DP' : 'Jumlah Pelunasan';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(amountLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(_formatRupiah(amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFCC0000))),
                  ]),
                ]),
              ),
              const SizedBox(height: 4),
              const Text('BCA: 1234567890 a.n. NGEBUT.IN', style: TextStyle(fontSize: 12, color: Color(0xFF374151))),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (img != null) setModalState(() => selectedFile = File(img.path));
                },
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: selectedFile != null ? const Color(0xFF059669) : Colors.grey.shade300, width: 2, style: BorderStyle.values[selectedFile != null ? 0 : 1]),
                    borderRadius: BorderRadius.circular(12),
                    color: selectedFile != null ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
                  ),
                  child: selectedFile != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(selectedFile!, fit: BoxFit.cover))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.cloud_upload, size: 42, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Klik untuk pilih foto', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ]),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isUploading || selectedFile == null ? null : () async {
                  setModalState(() => isUploading = true);
                  try {
                    final bytes = await selectedFile!.readAsBytes();
                    if (bytes.length > 3 * 1024 * 1024) {
                      throw Exception('File terlalu besar. Maksimal 3MB.');
                    }
                    final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                    if (type == 'dp') {
                      await bp.uploadDp(bookingId, base64);
                    } else {
                      await bp.uploadPelunasan(bookingId, base64);
                    }
                    if (mounted) {
                      Navigator.pop(ctx);
                      _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('✅ Bukti ${type == 'dp' ? 'DP' : 'pelunasan'} berhasil dikirim!'),
                        backgroundColor: const Color(0xFF059669),
                      ));
                    }
                  } catch (e) {
                    setModalState(() => isUploading = false);
                    if (mounted) {
                      showDialog(context: context, builder: (_) => AlertDialog(
                        title: const Text('Upload Gagal'),
                        content: Text(e.toString().replaceFirst('Exception: ', '')),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: type == 'dp' ? const Color(0xFFCC0000) : const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Kirim Bukti ${type == 'dp' ? 'DP' : 'Pelunasan'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKwitansi(Map<String, dynamic> b) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => KwitansiScreen(booking: b),
    ));
  }
}
