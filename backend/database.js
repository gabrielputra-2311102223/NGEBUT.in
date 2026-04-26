const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const crypto = require('crypto');

function hashPassword(password) {
    return crypto.createHash('sha256').update(password).digest('hex');
}

// Mengubah nama file database agar membuat file baru dengan skema dan password tersandi
const dbPath = path.resolve(__dirname, 'database_v3.sqlite');
const db = new sqlite3.Database(dbPath, (err) => {
    if (err) {
        console.error('Error opening database', err.message);
    } else {
        console.log('Connected to the SQLite database.');
        
        // Create tables
        db.serialize(() => {
            // Users Table
            db.run(`CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nama TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                role TEXT DEFAULT 'user',
                no_telp TEXT,
                nik TEXT,
                sim TEXT,
                alamat TEXT,
                jk TEXT
            )`);

            // Insert admin user if not exists
            db.get(`SELECT id FROM users WHERE email = ?`, ['admin@gmail.com'], (err, row) => {
                if (!row) {
                    const hashedPassword = hashPassword('admin123');
                    db.run(`INSERT INTO users (nama, email, password, role) VALUES (?, ?, ?, ?)`,
                        ['Administrator', 'admin@gmail.com', hashedPassword, 'admin']);
                }
            });

            // Motor Table (Aligned with frontend schema)
            db.run(`CREATE TABLE IF NOT EXISTS motors (
                id INTEGER PRIMARY KEY,
                nama TEXT NOT NULL,
                harga INTEGER NOT NULL,
                desc TEXT,
                gambar TEXT,
                status TEXT DEFAULT 'available'
            )`);

            // Insert dummy motor data if empty
            db.get(`SELECT COUNT(*) as count FROM motors`, (err, row) => {
                if (row && row.count === 0) {
                    const defaultMotors = [
                        [1, 'Honda Vario 125', 75000, 'Irit & nyaman untuk harian', 'assets/img/motor2.jpg', 'available'],
                        [2, 'Honda Beat', 65000, 'Hemat bensin, lincah di perkotaan', 'assets/img/motor3.jpg', 'available'],
                        [3, 'Honda PCX 160', 130000, 'Premium, nyaman untuk touring', 'assets/img/motor6.jpg', 'available'],
                        [4, 'Yamaha NMAX', 120000, 'Nyaman & bertenaga', 'assets/img/motor4.jpg', 'available'],
                        [5, 'Aerox 155', 150000, 'Motor Matic tangguh', 'assets/img/motor7.jpg', 'available'],
                        [6, 'Suzuki Nex 125', 140000, 'Super Irit & ringan', 'assets/img/motor5.jpg', 'available']
                    ];
                    
                    const stmt = db.prepare(`INSERT INTO motors (id, nama, harga, desc, gambar, status) VALUES (?, ?, ?, ?, ?, ?)`);
                    defaultMotors.forEach(motor => {
                        stmt.run(motor);
                    });
                    stmt.finalize();
                }
            });

            // Booking Table (Aligned with frontend schema)
            db.run(`CREATE TABLE IF NOT EXISTS bookings (
                id TEXT PRIMARY KEY,
                motorId INTEGER,
                motorName TEXT,
                userId INTEGER,
                userName TEXT,
                harga INTEGER,
                totalHarga INTEGER,
                startDate TEXT,
                endDate TEXT,
                status TEXT DEFAULT 'confirm',
                createdAt TEXT
            )`);
        });
    }
});

module.exports = db;
