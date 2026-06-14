class Motor {
  final int id;
  final String nama;
  final int harga;
  final String deskripsi;
  final String gambar;
  final String status;
  final String kategori;

  Motor({
    required this.id,
    required this.nama,
    required this.harga,
    required this.deskripsi,
    required this.gambar,
    required this.status,
    required this.kategori,
  });

  factory Motor.fromJson(Map<String, dynamic> json) {
    // Safe int parse - handles int, double, or String from API
    int safeInt(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is int) return val;
      if (val is double) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    return Motor(
      id: safeInt(json['id'], 0),
      nama: (json['nama'] ?? 'Tanpa Nama').toString(),
      harga: safeInt(json['harga'], 0),
      deskripsi: (json['deskripsi'] ?? '').toString(),
      gambar: (json['gambar'] ?? '').toString(),
      status: (json['status'] ?? 'available').toString(),
      kategori: (json['kategori'] ?? 'umum').toString(),
    );
  }

  String get formattedHarga {
    return 'Rp ${harga.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}
