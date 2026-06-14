import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/motor_provider.dart';
import '../../providers/booking_provider.dart';
import '../auth/landing_screen.dart';
import '../user/profile_edit_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({Key? key}) : super(key: key);

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _currentIndex = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
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
            const Text('Owner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
              accountName: Text(auth.user?['nama'] ?? 'Owner', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(auth.user?['email'] ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: (auth.user?['foto_profil'] != null && auth.user!['foto_profil'].toString().isNotEmpty)
                    ? NetworkImage(auth.user!['foto_profil'].toString()) as ImageProvider
                    : null,
                child: (auth.user?['foto_profil'] == null || auth.user!['foto_profil'].toString().isEmpty)
                    ? const Icon(Icons.business, color: Color(0xFF1A1A1A))
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart),
              title: const Text('Laporan Bisnis'),
              selected: _currentIndex == 0,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Riwayat Transaksi'),
              selected: _currentIndex == 1,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil'),
              selected: _currentIndex == 2,
              selectedColor: const Color(0xFFCC0000),
              onTap: () {
                setState(() => _currentIndex = 2);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildOwnerDashboard(),
          _buildTransactionHistory(),
          _buildOwnerProfile(auth),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Widget _buildOwnerDashboard() {
    return Consumer2<MotorProvider, BookingProvider>(
      builder: (context, motorProv, bookingProv, _) {
        final allBookings = bookingProv.bookings;
        final successBookings = allBookings.where((b) => b['status'] == 'booked' || b['status'] == 'paid' || b['status'] == 'finished' || b['status'] == 'done').toList();
        
        int totalRevenue = 0;
        int revenueThisMonth = 0;
        int revenueLast12Months = 0;
        
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final startOf12MonthsAgo = DateTime(now.year - 1, now.month, 1);

        Map<String, int> motorBookingCount = {};
        Map<String, int> userBookingCount = {};
        
        int pendingCount = 0;
        int activeCount = 0;
        int finishedCount = 0;

        for (var b in allBookings) {
          final status = b['status'];
          if (status == 'pending') pendingCount++;
          else if (status == 'booked' || status == 'paid' || status == 'approved' || status == 'confirm') activeCount++;
          else if (status == 'finished' || status == 'done') finishedCount++;
        }

        for (var b in successBookings) {
          final amount = (b['totalHarga'] ?? b['total_harga'] ?? 0) is int 
              ? (b['totalHarga'] ?? b['total_harga'] ?? 0) as int
              : int.tryParse((b['totalHarga'] ?? b['total_harga']).toString()) ?? 0;
          totalRevenue += amount;

          final createdAt = DateTime.tryParse(b['createdAt'] ?? b['created_at'] ?? '') ?? now;
          if (createdAt.isAfter(startOfMonth) || createdAt.isAtSameMomentAs(startOfMonth)) {
            revenueThisMonth += amount;
          }
          if (createdAt.isAfter(startOf12MonthsAgo) || createdAt.isAtSameMomentAs(startOf12MonthsAgo)) {
            revenueLast12Months += amount;
          }

          final mId = (b['motorId'] ?? b['motor_id']).toString();
          motorBookingCount[mId] = (motorBookingCount[mId] ?? 0) + 1;

          final uId = (b['userId'] ?? b['user_id']).toString();
          userBookingCount[uId] = (userBookingCount[uId] ?? 0) + 1;
        }

        // Find Best Seller Motor
        String bestMotorId = '';
        int maxMotorCount = 0;
        motorBookingCount.forEach((id, count) {
          if (count > maxMotorCount) {
            maxMotorCount = count;
            bestMotorId = id;
          }
        });
        
        // Find Best User
        String bestUserId = '';
        int maxUserCount = 0;
        userBookingCount.forEach((id, count) {
          if (count > maxUserCount) {
            maxUserCount = count;
            bestUserId = id;
          }
        });

        final bestMotor = motorProv.motors.where((m) => m.id.toString() == bestMotorId).firstOrNull;

        return RefreshIndicator(
          onRefresh: () async {
            await motorProv.fetchMotors();
            await bookingProv.fetchAllBookings();
          },
          color: const Color(0xFFCC0000),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Laporan Keuangan & Bisnis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                          SizedBox(height: 4),
                          Text('Performa bisnis real-time', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan Excel berhasil diunduh (Simulasi)')));
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Excel'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534), foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Revenue cards
                _buildRevenueCard('Pendapatan Total', totalRevenue, [const Color(0xFF10B981), const Color(0xFF059669)]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSmallRevenueCard('Bulan Ini', revenueThisMonth, Icons.calendar_month, const Color(0xFF3B82F6))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSmallRevenueCard('12 Bulan Terakhir', revenueLast12Months, Icons.history, const Color(0xFFF59E0B))),
                  ],
                ),
                const SizedBox(height: 24),

                const Text('Status Booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatusCard('Pending', pendingCount, const Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    _buildStatusCard('Aktif', activeCount, const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _buildStatusCard('Selesai', finishedCount, const Color(0xFF10B981)),
                  ],
                ),
                const SizedBox(height: 24),
                
                const Text('Top Performa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.star, color: Color(0xFFCC0000))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Motor Terlaris', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(bestMotor?.nama ?? 'Belum Ada', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('$maxMotorCount kali disewa', style: const TextStyle(color: Color(0xFFCC0000), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person, color: Color(0xFF0284C7))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pelanggan Paling Aktif', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(bestUserId.isEmpty ? 'Belum Ada' : 'User ID: $bestUserId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('$maxUserCount kali menyewa', style: const TextStyle(color: Color(0xFF0284C7), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRevenueCard(String title, int amount, List<Color> gradient) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_formatCurrency(amount), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSmallRevenueCard(String title, int amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(_formatCurrency(amount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
        final bookings = provider.bookings;
        if (bookings.isEmpty) return const Center(child: Text('Belum ada transaksi.'));

        return RefreshIndicator(
          onRefresh: provider.fetchAllBookings,
          color: const Color(0xFFCC0000),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final b = bookings[index];
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
                        Text('Order #${b['id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(_formatCurrency((b['totalHarga'] as num?)?.toInt() ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      ],
                    ),
                    const Divider(height: 20),
                    Text('${(b['startDate'] ?? '-').toString().split('T')[0]} s/d ${(b['endDate'] ?? '-').toString().split('T')[0]}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Status: ${(b['status'] ?? '').toString().toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOwnerProfile(AuthProvider auth) {
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
                backgroundImage: auth.user?['foto'] != null ? NetworkImage(auth.user!['foto']) : null,
                child: auth.user?['foto'] == null ? const Icon(Icons.business, size: 40, color: Color(0xFFCC0000)) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(auth.user?['nama'] ?? 'Owner', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
            child: const Text('OWNER', style: TextStyle(color: Color(0xFFCC0000), fontWeight: FontWeight.bold, fontSize: 12)),
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
