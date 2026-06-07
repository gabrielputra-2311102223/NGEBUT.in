import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).fetchUsers();
    });
  }

  void _deleteUser(BuildContext context, int userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengguna'),
        content: Text('Anda yakin ingin menghapus akun $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Provider.of<UserProvider>(context, listen: false).deleteUser(userId);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengguna dihapus')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));

        if (provider.users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Belum ada pengguna terdaftar', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.fetchUsers,
          color: const Color(0xFFCC0000),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = provider.users[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFFE4E6),
                      backgroundImage: user['foto'] != null ? NetworkImage(user['foto']) : null,
                      child: user['foto'] == null ? const Icon(Icons.person, color: Color(0xFFCC0000)) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['nama'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(user['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: user['role'] == 'admin' ? const Color(0xFFFEE2E2) : (user['role'] == 'owner' ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (user['role'] ?? 'user').toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold,
                                color: user['role'] == 'admin' ? const Color(0xFFCC0000) : (user['role'] == 'owner' ? Colors.white : Colors.grey.shade700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user['role'] != 'owner')
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUser(context, user['id'], user['nama'] ?? 'Tanpa Nama'),
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
}
