-- MIGRATION SCRIPT UNTUK FITUR OWNER, DP, DAN OTP
-- Jalankan script ini di phpMyAdmin Hostinger Anda

-- 1. Tambah kolom baru ke tabel Users
ALTER TABLE Users
ADD COLUMN email_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN otp_code VARCHAR(10) NULL,
ADD COLUMN otp_expires DATETIME NULL;

-- 2. Tambah kolom baru ke tabel Bookings
ALTER TABLE Bookings
ADD COLUMN dp_amount INT NULL,
ADD COLUMN dp_bukti LONGTEXT NULL,
ADD COLUMN status_pembayaran VARCHAR(50) DEFAULT 'menunggu_dp';

-- (Optional) Update existing Admin account agar otomatis terverifikasi
UPDATE Users SET email_verified = TRUE WHERE role = 'admin';

-- Selesai!
