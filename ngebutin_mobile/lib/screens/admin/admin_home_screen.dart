import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/motor_provider.dart';
import '../../providers/booking_provider.dart';
import '../auth/landing_screen.dart';
import '../user/profile_edit_screen.dart';
import 'admin_kendaraan_screen.dart';
import 'admin_approval_screen.dart';
import 'admin_pembayaran_screen.dart';
import 'admin_users_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      // Auto-refresh every 30 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshData());
    });
  }

  void _refreshData() {
    if (!mounted) return;
    Provider.of<MotorProvider>(context, listen: false).fetchMotors();
    Provider.of<BookingProvider>(context, listen: false).fetchAllBookings();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 28),
            const SizedBox(width: 8),
            const Text('Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
              accountName: Text(auth.user?['nama'] ?? 'Administrator', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(auth.user?['email'] ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: (auth.user?['foto_profil'] != null && auth.user!['foto_profil'].toString().isNotEmpty)
                    ? NetworkImage(auth.user!['foto_profil'].toString()) as ImageProvider
                    : null,
                child: (auth.user?['foto_profil'] == null || auth.user!['foto_profil'].toString().isEmpty)
                    ? const Icon(Icons.shield, color: Color(0xFF1A1A1A))
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _currentIndex == 0,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.motorcycle),
              title: const Text('Kelola Kendaraan'),
              selected: _currentIndex == 1,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Approval Booking'),
              selected: _currentIndex == 2,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Pembayaran'),
              selected: _currentIndex == 3,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manajemen User'),
              selected: _currentIndex == 4,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 4);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil'),
              selected: _currentIndex == 5,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 5);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          const AdminKendaraanScreen(),
          const AdminApprovalScreen(),
          const AdminPembayaranScreen(),
          const AdminUsersScreen(),
          _buildAdminProfile(auth),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Consumer2<MotorProvider, BookingProvider>(
      builder: (context, motorProv, bookingProv, _) {
        final allMotors = motorProv.motors;
        final allBookings = bookingProv.bookings;

        final totalMotor = allMotors.length;
        final available = allMotors.where((m) => m.status == 'available').length;
        final booked = allMotors.where((m) => m.status == 'booked').length;

        // Status counts — menggunakan status sebenarnya dari API
        final waiting = allBookings.where((b) {
          final s = b['status']?.toString() ?? '';
          final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
          return s == 'confirm' && (sp == 'dp_uploaded' || sp == 'verifikasi');
        }).length;

        final active = allBookings.where((b) {
          final s = b['status']?.toString() ?? '';
          final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
          return s == 'booked' && sp == 'dp_lunas';
        }).length;

        final returning = allBookings.where((b) => b['status']?.toString() == 'returning').length;
        final done = allBookings.where((b) => b['status']?.toString() == 'done').length;
        final menungguDP = allBookings.where((b) {
          final s = b['status']?.toString() ?? '';
          final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
          return s == 'confirm' && sp == 'menunggu_dp';
        }).length;

        // Pendapatan total dari booking selesai
        int totalPendapatan = 0;
        for (final b in allBookings.where((b) => b['status'] == 'done')) {
          totalPendapatan += ((b['totalHarga'] ?? b['total_harga'] ?? 0) as num).toInt();
        }

        // Recent 5 bookings
        final recent = List.from(allBookings).take(5).toList();

        return RefreshIndicator(
          onRefresh: () async {
            await motorProv.fetchMotors();
            await bookingProv.fetchAllBookings();
          },
          color: const Color(0xFFCC0000),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text('${allBookings.length} total transaksi • ${allMotors.length} kendaraan', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),

                // STATS ROW 1
                Row(children: [
                  _statCard('Total Kendaraan', totalMotor.toString(), Icons.motorcycle, const Color(0xFFCC0000)),
                  const SizedBox(width: 12),
                  _statCard('Tersedia', available.toString(), Icons.check_circle, const Color(0xFF10B981)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _statCard('Disewa', booked.toString(), Icons.directions_bike, const Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  _statCard('Menunggu DP', menungguDP.toString(), Icons.hourglass_empty, const Color(0xFFF59E0B)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _statCard('Approval DP', waiting.toString(), Icons.fact_check, const Color(0xFF8B5CF6)),
                  const SizedBox(width: 12),
                  _statCard('Dikembalikan', returning.toString(), Icons.undo, const Color(0xFFEC4899)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _statCard('Selesai', done.toString(), Icons.flag, const Color(0xFF6B7280)),
                  const SizedBox(width: 12),
                  // Pendapatan card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(left: BorderSide(color: Color(0xFF059669), width: 4)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.attach_money, color: Color(0xFF059669), size: 18),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Rp ${(totalPendapatan / 1000000).toStringAsFixed(1)}Jt',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                          ),
                          const SizedBox(height: 2),
                          const Text('Total Pendapatan', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 28),

                // RECENT BOOKINGS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Booking Terbaru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => setState(() => _currentIndex = 2),
                      child: const Text('Lihat Semua', style: TextStyle(color: Color(0xFFCC0000))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (recent.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('Belum ada booking', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ...recent.map((b) {
                    final s = b['status']?.toString() ?? '';
                    final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
                    final userName = b['userName']?.toString() ?? 'User #${b['userId'] ?? b['user_id']}';
                    final motorName = b['motorName']?.toString() ?? 'Motor';

                    Color badgeColor;
                    Color badgeFg;
                    String badgeText;

                    if (s == 'confirm' && sp == 'menunggu_dp') {
                      badgeColor = const Color(0xFFFEF08A); badgeFg = const Color(0xFF854D0E); badgeText = 'MENUNGGU DP';
                    } else if (s == 'confirm' && (sp == 'dp_uploaded' || sp == 'verifikasi')) {
                      badgeColor = const Color(0xFFBAE6FD); badgeFg = const Color(0xFF0369A1); badgeText = 'VERIFIKASI DP';
                    } else if (s == 'booked') {
                      badgeColor = const Color(0xFFBBF7D0); badgeFg = const Color(0xFF166534); badgeText = 'AKTIF';
                    } else if (s == 'returning') {
                      badgeColor = const Color(0xFFE9D5FF); badgeFg = const Color(0xFF6B21A8); badgeText = 'KEMBALI';
                    } else if (s == 'done') {
                      badgeColor = const Color(0xFFE5E7EB); badgeFg = const Color(0xFF374151); badgeText = 'SELESAI';
                    } else if (s == 'rejected') {
                      badgeColor = const Color(0xFFFEE2E2); badgeFg = const Color(0xFFCC0000); badgeText = 'DITOLAK';
                    } else {
                      badgeColor = Colors.grey.shade200; badgeFg = Colors.grey.shade700; badgeText = s.toUpperCase();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long, color: Color(0xFFCC0000), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('#${b['id']} · $userName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(motorName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                            child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg)),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList() {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
        }
        final bookings = provider.bookings;
        if (bookings.isEmpty) {
          return const Center(child: Text('Belum ada booking.'));
        }
        return RefreshIndicator(
          onRefresh: provider.fetchAllBookings,
          color: const Color(0xFFCC0000),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final b = bookings[index];
              String statusText = (b['status'] ?? '').toString().toUpperCase();
              Color badgeColor = Colors.grey.shade200;
              Color textColor = Colors.grey.shade800;

              if (b['status'] == 'pending') {
                badgeColor = const Color(0xFFFEF08A);
                textColor = const Color(0xFF854D0E);
                statusText = 'PENDING';
              } else if (b['status'] == 'booked' || b['status'] == 'paid') {
                badgeColor = const Color(0xFFBBF7D0);
                textColor = const Color(0xFF166534);
                statusText = 'AKTIF';
              } else if (b['status'] == 'finished') {
                badgeColor = const Color(0xFFE5E7EB);
                textColor = const Color(0xFF374151);
                statusText = 'SELESAI';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Booking #${b['id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                          child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('User ID: ${b['userId']}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 16, color: Color(0xFFCC0000)),
                        const SizedBox(width: 8),
                        Flexible(child: Text('${(b['startDate'] ?? '-').toString().split('T')[0]} s/d ${(b['endDate'] ?? '-').toString().split('T')[0]}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(color: Colors.grey)),
                        Text('Rp ${b['totalHarga']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAdminProfile(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF1A1A1A),
                  backgroundImage: auth.user?['foto_profil'] != null && auth.user!['foto_profil'].toString().isNotEmpty
                      ? (auth.user!['foto_profil'].toString().startsWith('data:')
                          ? MemoryImage(base64Decode(auth.user!['foto_profil'].split(',').last))
                          : NetworkImage(auth.user!['foto_profil'])) as ImageProvider
                      : null,
                  child: auth.user?['foto_profil'] == null || auth.user!['foto_profil'].toString().isEmpty
                      ? const Icon(Icons.shield, size: 40, color: Colors.white)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(auth.user?['nama'] ?? 'Administrator', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFCC0000), borderRadius: BorderRadius.circular(20)),
            child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Text(auth.user?['email'] ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: Color(0xFFCC0000)),
              title: const Text('Edit Profil'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LandingScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('KELUAR (LOGOUT)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE2E2),
                foregroundColor: const Color(0xFFCC0000),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
