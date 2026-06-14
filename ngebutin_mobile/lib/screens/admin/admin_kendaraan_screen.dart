import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/motor_provider.dart';
import '../../models/motor.dart';

class AdminKendaraanScreen extends StatelessWidget {
  const AdminKendaraanScreen({Key? key}) : super(key: key);

  void _showDeleteDialog(BuildContext context, Motor motor, MotorProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kendaraan'),
        content: Text('Anda yakin ingin menghapus ${motor.nama}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.deleteMotor(motor.id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kendaraan dihapus')));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
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
    return Consumer<MotorProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)));

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: provider.fetchMotors,
            color: const Color(0xFFCC0000),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.motors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final motor = provider.motors[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          image: motor.gambar.isNotEmpty ? DecorationImage(
                            image: motor.gambar.startsWith('data:image') 
                                ? MemoryImage(base64Decode(motor.gambar.split(',')[1])) 
                                : NetworkImage(motor.gambar) as ImageProvider,
                            fit: BoxFit.cover,
                          ) : null,
                        ),
                        child: motor.gambar.isEmpty ? const Icon(Icons.motorcycle, color: Colors.grey) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(motor.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(motor.formattedHarga, style: const TextStyle(color: Color(0xFFCC0000))),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: motor.status == 'available' ? Colors.green.shade100 : (motor.status == 'service' ? Colors.orange.shade100 : Colors.blue.shade100),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                motor.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold,
                                  color: motor.status == 'available' ? Colors.green.shade800 : (motor.status == 'service' ? Colors.orange.shade800 : Colors.blue.shade800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AdminMotorFormScreen(motor: motor)));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteDialog(context, motor, provider),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFFCC0000),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMotorFormScreen()));
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}

class AdminMotorFormScreen extends StatefulWidget {
  final Motor? motor;
  const AdminMotorFormScreen({Key? key, this.motor}) : super(key: key);

  @override
  State<AdminMotorFormScreen> createState() => _AdminMotorFormScreenState();
}

class _AdminMotorFormScreenState extends State<AdminMotorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _kategoriCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();
  String _status = 'available';
  String _base64Image = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.motor != null) {
      _namaCtrl.text = widget.motor!.nama;
      // Normalize kategori ke PascalCase agar cocok dengan dropdown options
      final rawKat = widget.motor!.kategori.trim();
      const validCategories = ['Matic', 'Manual', 'Sport'];
      final normalized = validCategories.firstWhere(
        (c) => c.toLowerCase() == rawKat.toLowerCase(),
        orElse: () => rawKat.isNotEmpty ? rawKat : '',
      );
      _kategoriCtrl.text = normalized;
      _hargaCtrl.text = widget.motor!.harga.toString();
      _deskripsiCtrl.text = widget.motor!.deskripsi;
      _status = widget.motor!.status;
      _base64Image = widget.motor!.gambar;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Saat tambah baru, wajib ada gambar. Saat edit, boleh pakai gambar lama.
    if (_base64Image.isEmpty && widget.motor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih gambar motor terlebih dahulu'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<MotorProvider>(context, listen: false);
      final motorData = Motor(
        id: widget.motor?.id ?? 0,
        nama: _namaCtrl.text.trim(),
        kategori: _kategoriCtrl.text,
        harga: int.parse(_hargaCtrl.text.replaceAll(RegExp(r'[^\d]'), '')),
        deskripsi: _deskripsiCtrl.text.trim(),
        gambar: _base64Image,
        status: _status,
      );

      if (widget.motor == null) {
        await provider.addMotor(motorData);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Kendaraan berhasil ditambahkan!'), backgroundColor: Colors.green));
      } else {
        await provider.updateMotor(motorData);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Kendaraan berhasil diperbarui!'), backgroundColor: Colors.green));
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.motor == null ? 'Tambah Kendaraan' : 'Edit Kendaraan', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _base64Image.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap untuk upload gambar', style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _base64Image.startsWith('data:image') 
                              ? Image.memory(base64Decode(_base64Image.split(',')[1]), fit: BoxFit.cover)
                              : Image.network(_base64Image, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _namaCtrl,
                decoration: const InputDecoration(labelText: 'Nama Motor', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _kategoriCtrl.text.isNotEmpty ? _kategoriCtrl.text : null,
                decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                items: const [
                  DropdownMenuItem(value: 'Matic', child: Text('Matic')),
                  DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                  DropdownMenuItem(value: 'Sport', child: Text('Sport')),
                ],
                onChanged: (val) => setState(() => _kategoriCtrl.text = val ?? ''),
                validator: (v) => (v == null || v.isEmpty) ? 'Pilih kategori' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hargaCtrl,
                decoration: const InputDecoration(labelText: 'Harga per Hari', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'available', child: Text('Tersedia')),
                  DropdownMenuItem(value: 'booked', child: Text('Sedang Disewa')),
                  DropdownMenuItem(value: 'service', child: Text('Dalam Perbaikan (Servis)')),
                ],
                onChanged: (val) => setState(() => _status = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deskripsiCtrl,
                decoration: const InputDecoration(labelText: 'Deskripsi', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFCC0000),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SIMPAN KENDARAAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
