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
    return Motor(
      id: json['id'],
      nama: json['nama'] ?? 'Tanpa Nama',
      harga: json['harga'] ?? 0,
      deskripsi: json['deskripsi'] ?? '',
      gambar: json['gambar'] ?? '',
      status: json['status'] ?? 'available',
      kategori: json['kategori'] ?? 'umum',
    );
  }

  String get formattedHarga {
    return 'Rp ${harga.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}
