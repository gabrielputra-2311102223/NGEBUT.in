import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loadingProfile = false;

  @override
  void initState() {
    super.initState();
    // Fetch full profile to get email
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchFullProfile());
  }

  Future<void> _fetchFullProfile() async {
    if (!mounted) return;
    setState(() => _loadingProfile = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).fetchFullProfile();
    } catch (_) {}
    if (mounted) setState(() => _loadingProfile = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final foto = user?['foto_profil'] ?? user?['foto'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Profil Akun', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFFFE4E6),
                    backgroundImage: foto != null && foto.toString().isNotEmpty
                        ? (foto.toString().startsWith('data:image')
                            ? MemoryImage(Uri.parse(foto.toString()).data!.contentAsBytes())
                            : NetworkImage(foto.toString()) as ImageProvider)
                        : null,
                    child: (foto == null || foto.toString().isEmpty)
                        ? const Icon(Icons.person, size: 50, color: Color(0xFFCC0000))
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?['nama'] ?? 'Guest User',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?['email'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (user?['role'] ?? 'user').toString().toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCC0000)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline, color: Color(0xFFCC0000)),
                          title: const Text('Edit Profil'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
                            // Refresh profile after edit
                            if (mounted) _fetchFullProfile();
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.security, color: Color(0xFFCC0000)),
                          title: const Text('Keamanan Akun'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fitur keamanan akan segera hadir')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await auth.logout();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
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
            ),
    );
  }
}
