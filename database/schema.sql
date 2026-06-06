-- SCHEMA FOR MYSQL DATABASE (NGEBUT.IN)

-- 1. Tabel Users
CREATE TABLE Users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nama VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'user', -- 'admin', 'owner', atau 'user'
    foto_profil LONGTEXT NULL, -- Base64 atau URL foto profil
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabel Motors
CREATE TABLE Motors (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nama VARCHAR(100) NOT NULL,
    harga INT NOT NULL,
    deskripsi LONGTEXT,
    gambar LONGTEXT,
    status VARCHAR(20) DEFAULT 'available', -- 'available' atau 'booked'
    kategori VARCHAR(50) -- 'sport', 'matic', 'bebek'
);

-- 3. Tabel Bookings
CREATE TABLE Bookings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    motor_id INT,
    tgl_mulai DATE NOT NULL,
    tgl_selesai DATE NOT NULL,
    total_harga INT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'completed', 'confirm', 'booked', 'paid', 'returning', 'done', 'cancelled'
    bukti_pembayaran VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (motor_id) REFERENCES Motors(id) ON DELETE CASCADE
);

-- 4. Initial Data (Motors)
INSERT INTO Motors (nama, harga, deskripsi, gambar, status, kategori)
VALUES 
('Honda Vario 125', 75000, 'Irit & nyaman untuk harian', 'assets/img/motor2.jpg', 'available', 'matic'),
('Honda Beat', 65000, 'Hemat bensin, lincah di perkotaan', 'assets/img/motor3.jpg', 'available', 'matic'),
('Honda PCX 160', 130000, 'Premium, nyaman untuk touring', 'assets/img/motor6.jpg', 'available', 'matic'),
('Yamaha NMAX', 120000, 'Nyaman & bertenaga', 'assets/img/motor4.jpg', 'available', 'matic'),
('Aerox 155', 150000, 'Motor Matic tangguh', 'assets/img/motor7.jpg', 'available', 'matic');
