-- SCHEMA FOR AZURE SQL DATABASE (NGEBUT.IN)

-- 1. Tabel Users
CREATE TABLE Users (
    id INT PRIMARY KEY IDENTITY(1,1),
    nama NVARCHAR(100) NOT NULL,
    email NVARCHAR(100) UNIQUE NOT NULL,
    password NVARCHAR(255) NOT NULL,
    role NVARCHAR(20) DEFAULT 'user', -- 'admin' atau 'user'
    created_at DATETIME DEFAULT GETDATE()
);

-- 2. Tabel Motors
CREATE TABLE Motors (
    id INT PRIMARY KEY IDENTITY(1,1),
    nama NVARCHAR(100) NOT NULL,
    harga INT NOT NULL,
    deskripsi NVARCHAR(MAX),
    gambar NVARCHAR(255),
    status NVARCHAR(20) DEFAULT 'available', -- 'available' atau 'booked'
    kategori NVARCHAR(50) -- 'sport', 'matic', 'bebek'
);

-- 3. Tabel Bookings
CREATE TABLE Bookings (
    id INT PRIMARY KEY IDENTITY(1,1),
    user_id INT FOREIGN KEY REFERENCES Users(id),
    motor_id INT FOREIGN KEY REFERENCES Motors(id),
    tgl_mulai DATE NOT NULL,
    tgl_selesai DATE NOT NULL,
    total_harga INT NOT NULL,
    status NVARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'completed'
    bukti_pembayaran NVARCHAR(255),
    created_at DATETIME DEFAULT GETDATE()
);

-- 4. Initial Data (Motors)
INSERT INTO Motors (nama, harga, deskripsi, gambar, status, kategori)
VALUES 
('Honda Vario 125', 75000, 'Irit & nyaman untuk harian', 'assets/img/motor2.jpg', 'available', 'matic'),
('Honda Beat', 65000, 'Hemat bensin, lincah di perkotaan', 'assets/img/motor3.jpg', 'available', 'matic'),
('Honda PCX 160', 130000, 'Premium, nyaman untuk touring', 'assets/img/motor6.jpg', 'available', 'matic'),
('Yamaha NMAX', 120000, 'Nyaman & bertenaga', 'assets/img/motor4.jpg', 'available', 'matic'),
('Aerox 155', 150000, 'Motor Matic tangguh', 'assets/img/motor7.jpg', 'available', 'matic');
