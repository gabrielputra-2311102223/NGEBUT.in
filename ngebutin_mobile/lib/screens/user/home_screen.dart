import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/motor_provider.dart';
import '../../providers/booking_provider.dart';
import 'motor_detail_screen.dart';
import 'booking_saya_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  final List<Map<String, dynamic>> _categories = [
    {'label': 'Semua',  'icon': Icons.motorcycle},
    {'label': 'Matic',  'icon': Icons.speed},
    {'label': 'Manual', 'icon': Icons.settings},
    {'label': 'Sport',  'icon': Icons.bolt},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MotorProvider>(context, listen: false).fetchMotors();
      _refreshUserBookings();
    });
  }

  void _refreshUserBookings() {
    if (!mounted) return;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      final uid = (user['id'] as num).toInt();
      Provider.of<BookingProvider>(context, listen: false).fetchMyBookings(uid);
    }
  }

  Widget _buildImage(String? gambar) {
    if (gambar == null || gambar.isEmpty) {
      return const Icon(Icons.motorcycle, size: 50, color: Colors.grey);
    }
    try {
      if (gambar.startsWith('data:image')) {
        final splitted = gambar.split(',');
        if (splitted.length > 1) {
          return Image.memory(
            base64Decode(splitted[1]),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.motorcycle, size: 50, color: Colors.grey),
          );
        }
      }
      return Image.network(
        gambar,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.motorcycle, size: 50, color: Colors.grey),
      );
    } catch (_) {
      return const Icon(Icons.motorcycle, size: 50, color: Colors.grey);
    }
  }

  Widget _buildKatalog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    return Consumer<MotorProvider>(
      builder: (context, motorProvider, child) {
        if (motorProvider.isLoading && motorProvider.motors.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
        }

        // Filter kategori: toleransi 'metic', 'matic', 'Matic' semua cocok
        final motors = motorProvider.motors.where((m) {
          final k = m.kategori.toLowerCase().trim();
          if (_selectedCategory != 'Semua') {
            final s = _selectedCategory.toLowerCase();
            if (s == 'matic') {
              // Cocok: matic, metic, matik, automatic, scooter
              if (!k.contains('mat') && !k.contains('met') && !k.contains('atik') && k != 'automatic' && !k.contains('scooter')) return false;
            } else if (s == 'manual') {
              if (!k.contains('man') && !k.contains('bebek') && !k.contains('cub')) return false;
            } else if (s == 'sport') {
              if (!k.contains('sport') && !k.contains('racing') && !k.contains('naked')) return false;
            }
          }
          if (_searchQuery.isNotEmpty && !m.nama.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: motorProvider.fetchMotors,
          color: const Color(0xFFCC0000),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFCC0000),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${user?['nama'] ?? 'User'}! 👋',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mau sewa motor apa hari ini?',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: const InputDecoration(
                            icon: Icon(Icons.search, color: Colors.grey),
                            hintText: 'Cari motor impianmu...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // SEWA AKTIF BANNER (seperti activeRentalArea di website)
                Consumer<BookingProvider>(
                  builder: (ctx, bp, _) {
                    final active = bp.bookings.where((b) {
                      final s = b['status']?.toString() ?? '';
                      return s == 'pending' || s == 'confirmed' || s == 'returning';
                    }).toList();
                    if (active.isEmpty) return const SizedBox.shrink();
                    final b = active.first;
                    final s = b['status']?.toString() ?? '';
                    final sp = (b['statusPembayaran'] ?? b['status_pembayaran'] ?? '').toString();
                    final motorName = (b['motorName'] ?? b['motor_name'] ?? 'Motor').toString();
                    String statusText;
                    Color cardColor;
                    Color textColor;
                    IconData icon;
                    if (s == 'pending' && sp == 'menunggu_dp') {
                      statusText = '⏳ Segera upload bukti DP untuk $motorName'; cardColor = const Color(0xFFFEF9C3); textColor = const Color(0xFF854D0E); icon = Icons.upload_file;
                    } else if (s == 'pending') {
                      statusText = '🔍 DP sedang diverifikasi - $motorName'; cardColor = const Color(0xFFDBEAFE); textColor = const Color(0xFF1E40AF); icon = Icons.hourglass_top;
                    } else if (s == 'confirmed') {
                      statusText = '🏍️ Kamu sedang menyewa $motorName'; cardColor = const Color(0xFFDCFCE7); textColor = const Color(0xFF166534); icon = Icons.motorcycle;
                    } else {
                      statusText = '↩️ $motorName dalam proses pengembalian'; cardColor = const Color(0xFFEDE9FE); textColor = const Color(0xFF6B21A8); icon = Icons.undo;
                    }
                    return GestureDetector(
                      onTap: () => setState(() => _currentIndex = 1),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1.5)),
                        child: Row(children: [
                          Icon(icon, color: textColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(statusText, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13))),
                          Icon(Icons.arrow_forward_ios, color: textColor, size: 13),
                        ]),
                      ),
                    );
                  },
                ),

                // Category Filter
                SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final label = cat['label'] as String;
                      final icon = cat['icon'] as IconData;
                      final isSelected = label == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = label),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFCC0000) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? const Color(0xFFCC0000) : Colors.grey.shade300),
                              boxShadow: isSelected ? [const BoxShadow(color: Color(0x33CC0000), blurRadius: 8, offset: Offset(0, 2))] : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey.shade600),
                                const SizedBox(width: 5),
                                Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Semua Kendaraan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${motors.length} unit', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),

                if (motors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('Tidak ada motor yang sesuai', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: motors.length,
                    itemBuilder: (context, index) {
                      final motor = motors[index];
                      final isAvailable = motor.status == 'available';
                      final isService = motor.status == 'service';

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => MotorDetailScreen(motor: motor)),
                          );
                        },
                        child: Card(
                          elevation: 3,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Stack(
                                  children: [
                                    SizedBox.expand(
                                      child: Container(
                                        color: Colors.grey.shade100,
                                        child: _buildImage(motor.gambar),
                                      ),
                                    ),
                                    // Status Badge
                                    Positioned(
                                      top: 8, right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? const Color(0xFF166534)
                                              : isService
                                                  ? Colors.orange.shade700
                                                  : const Color(0xFFCC0000),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isAvailable ? 'TERSEDIA' : isService ? 'SERVIS' : 'DISEWA',
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            motor.nama,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            motor.kategori,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                motor.formattedHarga,
                                                style: const TextStyle(color: Color(0xFFCC0000), fontWeight: FontWeight.w900, fontSize: 13),
                                              ),
                                              const Text('/hari', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 7),
                                        decoration: BoxDecoration(
                                          color: isAvailable ? const Color(0xFFCC0000) : Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          isAvailable ? 'Sewa Sekarang' : 'Tidak Tersedia',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isAvailable ? Colors.white : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Active booking count badge
    final bookingProv = Provider.of<BookingProvider>(context);
    final activeCount = bookingProv.bookings.where((b) {
      final s = b['status']?.toString() ?? '';
      return s == 'pending' || s == 'confirmed' || s == 'returning';
    }).length;

    final screens = [
      _buildKatalog(),
      const BookingSayaScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _currentIndex == 0
          ? AppBar(
              title: Row(
                children: [
                  Image.asset('assets/logo.png', height: 28),
                  const SizedBox(width: 8),
                  const Text('Ngebut.in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                ],
              ),
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1 || index == 2) _refreshUserBookings();
        },
        selectedItemColor: const Color(0xFFCC0000),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.motorcycle), label: 'Katalog'),
          BottomNavigationBarItem(
            icon: activeCount > 0
                ? Badge(
                    label: Text('$activeCount'),
                    child: const Icon(Icons.bookmark_outlined),
                  )
                : const Icon(Icons.bookmark_outlined),
            label: 'Booking Saya',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
