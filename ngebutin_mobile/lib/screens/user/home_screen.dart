import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/motor_provider.dart';
import '../auth/login_screen.dart';
import 'motor_detail_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MotorProvider>(context, listen: false).fetchMotors();
    });
  }

  Widget _buildImage(String base64String) {
    try {
      if (base64String.startsWith('data:image')) {
        final splitted = base64String.split(',');
        return Image.memory(
          base64Decode(splitted[1]),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.motorcycle, size: 50, color: Colors.grey),
        );
      }
      return Image.network(
        base64String,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.motorcycle, size: 50, color: Colors.grey),
      );
    } catch (e) {
      return const Icon(Icons.motorcycle, size: 50, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halo, ${user?['nama'] ?? 'User'}!', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                const Text('Mau sewa motor apa hari ini?', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
      body: _currentIndex == 0 ? Consumer<MotorProvider>(
        builder: (context, motorProvider, child) {
          if (motorProvider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));
          }

          final motors = motorProvider.motors.where((m) => m.status == 'available').toList();

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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                        const Text(
                          'Sewa Motor Mudah & Cepat',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pilih dari koleksi motor Honda terbaru kami untuk perjalanan Anda.',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('100% Aman & Terpercaya', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Text(
                      'Motor Tersedia',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                    ),
                  ),

                  if (motors.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('Maaf, tidak ada motor yang tersedia saat ini.')),
                    )
                  else
                    GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: motors.length,
                      itemBuilder: (context, index) {
                        final motor = motors[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MotorDetailScreen(motor: motor),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 4,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Container(
                                    color: Colors.white,
                                    child: _buildImage(motor.gambar),
                                  ),
                                ),
                                Expanded(
                                  flex: 6,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              motor.nama,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  motor.formattedHarga,
                                                  style: const TextStyle(color: Color(0xFFCC0000), fontWeight: FontWeight.w900, fontSize: 15),
                                                ),
                                                const Text('/hari', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF9FAFB),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE5E7EB)),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Sewa Sekarang',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
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
                    const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ) : _currentIndex == 1 ? const HistoryScreen() : const ProfileScreen(), // End body condition
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFFCC0000),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.motorcycle),
            label: 'Katalog',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
