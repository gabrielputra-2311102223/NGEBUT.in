const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const ExcelJS = require('exceljs');
const { poolPromise } = require('./db');
const { generateOTP, sendOtpEmail, sendPasswordChangeNotification, sendBookingNotification, sendResetPasswordOtp } = require('./email');

const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

const JWT_SECRET = process.env.JWT_SECRET || 'ngebutin_super_secret_123';

const admin = require('firebase-admin');
const fs = require('fs');

let fcmInitialized = false;
try {
    if (fs.existsSync('./firebase-service-account.json')) {
        const serviceAccount = require('./firebase-service-account.json');
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        fcmInitialized = true;
        console.log("Firebase Admin SDK initialized successfully.");
    } else {
        console.warn("firebase-service-account.json not found. Push notifications will be skipped.");
    }
} catch (e) {
    console.error("Error initializing Firebase Admin:", e.message);
}

// Auto-add fcm_token column
poolPromise.query('ALTER TABLE Users ADD COLUMN fcm_token VARCHAR(255) NULL').catch(() => {});



// --- AUTH ROUTES ---

// Register Step 1: Simpan user sementara + kirim OTP
app.post('/api/auth/register', async (req, res) => {
    try {
        const { nama, email, password } = req.body;

        // Cek apakah email sudah terdaftar
        const [existing] = await poolPromise.query('SELECT id, email_verified FROM Users WHERE email = ?', [email]);
        
        if (existing.length > 0) {
            if (existing[0].email_verified) {
                return res.status(400).json({ error: 'Email sudah terdaftar' });
            }
            // Jika belum verified, hapus dan biarkan register ulang
            await poolPromise.query('DELETE FROM Users WHERE email = ? AND email_verified = 0', [email]);
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const otpCode = generateOTP();
        const otpExpires = new Date(Date.now() + 10 * 60 * 1000); // 10 menit

        // Insert user dengan status belum verified
        await poolPromise.query(
            'INSERT INTO Users (nama, email, password, role, email_verified, otp_code, otp_expires) VALUES (?, ?, ?, \'user\', 0, ?, ?)',
            [nama, email, hashedPassword, otpCode, otpExpires]
        );

        // Kirim OTP ke email
        try {
            await sendOtpEmail(email, otpCode);
        } catch (emailErr) {
            console.error('Email send error:', emailErr.message);
            // Tetap lanjut meskipun email gagal (user bisa minta resend)
        }

        res.status(201).json({ message: 'OTP telah dikirim ke email Anda', requireOtp: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Register Step 2: Verifikasi OTP
app.post('/api/auth/verify-otp', async (req, res) => {
    try {
        const { email, otp } = req.body;

        const [rows] = await poolPromise.query(
            'SELECT * FROM Users WHERE email = ? AND email_verified = 0',
            [email]
        );

        if (rows.length === 0) {
            return res.status(400).json({ error: 'Email tidak ditemukan atau sudah terverifikasi' });
        }

        const user = rows[0];

        // Cek apakah OTP expired
        if (new Date() > new Date(user.otp_expires)) {
            return res.status(400).json({ error: 'Kode OTP sudah kedaluwarsa. Silakan daftar ulang.' });
        }

        // Cek apakah OTP cocok
        if (user.otp_code !== otp) {
            return res.status(400).json({ error: 'Kode OTP salah' });
        }

        // Verifikasi berhasil
        await poolPromise.query(
            'UPDATE Users SET email_verified = 1, otp_code = NULL, otp_expires = NULL WHERE email = ?',
            [email]
        );

        res.json({ message: 'Email berhasil diverifikasi! Silakan login.' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Login (hanya untuk user yang sudah verified)
app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        
        const [rows] = await poolPromise.query(
            'SELECT * FROM Users WHERE email = ?', 
            [email]
        );

        const user = rows[0];
        if (!user || !(await bcrypt.compare(password, user.password))) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Cek apakah email sudah diverifikasi (kecuali admin/owner, langsung boleh login)
        if (user.role === 'user' && !user.email_verified) {
            return res.status(403).json({ error: 'Email belum diverifikasi. Silakan cek inbox Anda.' });
        }

        const token = jwt.sign({ id: user.id, role: user.role, nama: user.nama }, JWT_SECRET, { expiresIn: '7d' });
        res.json({ token, user: { id: user.id, nama: user.nama, role: user.role, foto_profil: user.foto_profil } });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Lupa Password (Request OTP)
app.post('/api/auth/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        
        const [rows] = await poolPromise.query('SELECT * FROM Users WHERE email = ?', [email]);
        if (rows.length === 0) {
            return res.status(404).json({ error: 'Email tidak terdaftar.' });
        }

        const user = rows[0];
        const otpCode = generateOTP();
        const otpExpires = new Date(Date.now() + 10 * 60 * 1000); // 10 menit

        // Update otp ke database
        await poolPromise.query(
            'UPDATE Users SET otp_code = ?, otp_expires = ? WHERE email = ?',
            [otpCode, otpExpires, email]
        );

        // Kirim OTP via email
        try {
            await sendResetPasswordOtp(email, otpCode, user.nama);
        } catch (emailErr) {
            console.error('Email send error:', emailErr.message);
            // Tetap lanjut meskipun email error
        }

        res.json({ message: 'Kode OTP untuk reset password telah dikirim ke email Anda.' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Reset Password (Verify OTP & Set New Password)
app.post('/api/auth/reset-password', async (req, res) => {
    try {
        const { email, otp, newPassword } = req.body;

        const [rows] = await poolPromise.query('SELECT * FROM Users WHERE email = ?', [email]);
        if (rows.length === 0) {
            return res.status(404).json({ error: 'Email tidak ditemukan.' });
        }

        const user = rows[0];

        // Cek apakah OTP expired
        if (!user.otp_code || !user.otp_expires || new Date() > new Date(user.otp_expires)) {
            return res.status(400).json({ error: 'Kode OTP sudah tidak valid atau kedaluwarsa. Silakan minta kode baru.' });
        }

        // Cek kecocokan OTP
        if (user.otp_code !== otp) {
            return res.status(400).json({ error: 'Kode OTP salah.' });
        }

        // Enkripsi password baru
        const hashedPassword = await bcrypt.hash(newPassword, 10);

        // Update password dan bersihkan OTP
        await poolPromise.query(
            'UPDATE Users SET password = ?, otp_code = NULL, otp_expires = NULL WHERE email = ?',
            [hashedPassword, email]
        );

        // Kirim notifikasi password berhasil diubah
        try {
            await sendPasswordChangeNotification(email, user.nama);
        } catch (e) {
            console.error('Password notification email error:', e.message);
        }

        res.json({ message: 'Password berhasil direset! Silakan login.' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- MOTOR ROUTES ---

app.get('/api/motors', async (req, res) => {
    try {
        const [rows] = await poolPromise.query('SELECT * FROM Motors');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- BOOKING ROUTES ---

app.get('/api/bookings', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(`
            SELECT b.*, u.nama as userName, u.email as userEmail, m.nama as motorNama, m.harga 
            FROM Bookings b 
            LEFT JOIN Users u ON b.user_id = u.id 
            LEFT JOIN Motors m ON b.motor_id = m.id
            ORDER BY b.created_at DESC
        `);
        // Map to format expected by frontend
        const bookings = rows.map(b => ({
            id: b.id,
            motorId: b.motor_id,
            motorName: b.motorNama,
            userId: b.user_id,
            userName: b.userName,
            userEmail: b.userEmail,
            harga: b.harga,
            totalHarga: b.total_harga,
            dpAmount: b.dp_amount,
            dpBukti: b.dp_bukti,
            statusPembayaran: b.status_pembayaran,
            startDate: b.tgl_mulai,
            endDate: b.tgl_selesai,
            status: b.status,
            buktiPembayaran: b.bukti_pembayaran,
            createdAt: b.created_at
        }));
        res.json(bookings);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Create Booking dengan DP 50%
app.post('/api/bookings', async (req, res) => {
    try {
        const { user_id, motor_id, tgl_mulai, tgl_selesai, total_harga } = req.body;

        // Cek bentrok tanggal: apakah ada booking aktif pada motor yang sama di periode yang bertabrakan
        const [conflicts] = await poolPromise.query(
            `SELECT id FROM Bookings 
             WHERE motor_id = ? 
             AND status NOT IN ('cancelled', 'done', 'rejected') 
             AND tgl_mulai <= ? AND tgl_selesai >= ?`,
            [motor_id, tgl_selesai, tgl_mulai]
        );

        if (conflicts.length > 0) {
            return res.status(409).json({ error: 'Motor sudah dipesan pada tanggal tersebut. Silakan pilih tanggal lain.' });
        }

        // Hitung DP 50%
        const dpAmount = Math.ceil(total_harga * 0.5);
        
        await poolPromise.query(
            `INSERT INTO Bookings (user_id, motor_id, tgl_mulai, tgl_selesai, total_harga, dp_amount, status, status_pembayaran) 
             VALUES (?, ?, ?, ?, ?, ?, 'confirm', 'menunggu_dp')`,
            [user_id, motor_id, tgl_mulai, tgl_selesai, total_harga, dpAmount]
        );

        // Update status motor menjadi booked
        await poolPromise.query('UPDATE Motors SET status = ? WHERE id = ?', ['booked', motor_id]);

        // Kirim email notifikasi booking (async, jangan block response)
        try {
            const [userRows] = await poolPromise.query('SELECT nama, email FROM Users WHERE id = ?', [user_id]);
            const [motorRows] = await poolPromise.query('SELECT nama FROM Motors WHERE id = ?', [motor_id]);
            if (userRows.length && motorRows.length) {
                sendBookingNotification(userRows[0].email, userRows[0].nama, motorRows[0].nama, total_harga, dpAmount).catch(console.error);
            }
        } catch (e) { /* ignore email error */ }
            
        res.status(201).json({ message: 'Booking submitted. Silakan bayar DP 50%.', dpAmount });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Upload bukti DP
app.put('/api/bookings/:id/dp', async (req, res) => {
    try {
        const { dp_bukti } = req.body;
        const bookingId = req.params.id;

        await poolPromise.query(
            'UPDATE Bookings SET dp_bukti = ?, status_pembayaran = \'dp_uploaded\' WHERE id = ?',
            [dp_bukti, bookingId]
        );

        res.json({ message: 'Bukti DP berhasil diupload' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Admin: Approve DP
app.put('/api/bookings/:id/approve-dp', async (req, res) => {
    try {
        const bookingId = req.params.id;

        await poolPromise.query(
            'UPDATE Bookings SET status_pembayaran = \'dp_lunas\', status = \'booked\' WHERE id = ?',
            [bookingId]
        );

        res.json({ message: 'DP telah diverifikasi dan booking dikonfirmasi' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Update booking status (approve/reject/done)
app.put('/api/bookings/:id/status', async (req, res) => {
    try {
        const { status } = req.body;
        const bookingId = req.params.id;
        
        // 1. Get motor_id from this booking
        const [bookingRows] = await poolPromise.query(
            'SELECT motor_id FROM Bookings WHERE id = ?',
            [bookingId]
        );
        
        const motorId = bookingRows[0]?.motor_id;
        
        // 2. Update Booking Status
        let extraFields = '';
        if (status === 'done') {
            extraFields = ', status_pembayaran = \'lunas\'';
        } else if (status === 'cancelled') {
            extraFields = ', status_pembayaran = \'dibatalkan\'';
        }
        
        await poolPromise.query(
            `UPDATE Bookings SET status = ?${extraFields} WHERE id = ?`,
            [status, bookingId]
        );
            
        // 3. Update Motor Status accordingly
        if (motorId) {
            let motorStatus = 'available';
            if (status === 'booked' || status === 'paid' || status === 'returning') motorStatus = 'booked';
            else if (status === 'done' || status === 'confirm' || status === 'cancelled') motorStatus = 'available';
            
            await poolPromise.query(
                'UPDATE Motors SET status = ? WHERE id = ?',
                [motorStatus, motorId]
            );
        }
            
        res.json({ message: 'Booking and Motor status updated' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- USER ROUTES ---

// Get all users (for admin/owner)
app.get('/api/users', async (req, res) => {
    try {
        const [rows] = await poolPromise.query('SELECT id, nama, email, role, foto_profil, email_verified, created_at as createdAt FROM Users');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Update user profile (for own profile) + Notifikasi Email jika ganti password
app.put('/api/users/:id', async (req, res) => {
    try {
        const { nama, foto_profil, current_password, new_password } = req.body;
        const userId = req.params.id;

        // Get current user
        const [userRows] = await poolPromise.query('SELECT * FROM Users WHERE id = ?', [userId]);

        if (userRows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const currentUser = userRows[0];
        let hashedPassword = currentUser.password;
        let passwordChanged = false;

        // Password change logic
        if (new_password) {
            if (!current_password) {
                return res.status(400).json({ error: 'Current password required to change password' });
            }
            if (!(await bcrypt.compare(current_password, currentUser.password))) {
                return res.status(401).json({ error: 'Current password is incorrect' });
            }
            hashedPassword = await bcrypt.hash(new_password, 10);
            passwordChanged = true;
        }

        const foto = foto_profil !== undefined ? foto_profil : currentUser.foto_profil;

        await poolPromise.query(
            'UPDATE Users SET nama=?, foto_profil=?, password=? WHERE id=?',
            [nama || currentUser.nama, foto, hashedPassword, userId]
        );

        // Kirim notifikasi email jika password berubah
        if (passwordChanged) {
            try {
                await sendPasswordChangeNotification(currentUser.email, currentUser.nama);
            } catch (emailErr) {
                console.error('Password notification email error:', emailErr.message);
            }
        }

        res.json({ message: 'Profile updated successfully', user: { id: currentUser.id, nama: nama || currentUser.nama, foto_profil: foto } });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Update FCM Token
app.put('/api/users/:id/fcm-token', async (req, res) => {
    try {
        const { fcm_token } = req.body;
        const userId = req.params.id;
        await poolPromise.query('UPDATE Users SET fcm_token = ? WHERE id = ?', [fcm_token, userId]);
        res.json({ message: 'FCM Token updated' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Upload profile photo
app.post('/api/users/:id/photo', async (req, res) => {
    try {
        const { photo } = req.body;
        const userId = req.params.id;
        if (!photo) {
            return res.status(400).json({ error: 'Photo data required' });
        }

        await poolPromise.query('UPDATE Users SET foto_profil=? WHERE id=?', [photo, userId]);

        res.json({ message: 'Profile photo updated successfully', foto_profil: photo });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Get current user profile
app.get('/api/users/me/:id', async (req, res) => {
    try {
        const userId = req.params.id;
        const [rows] = await poolPromise.query('SELECT id, nama, email, role, foto_profil, created_at as createdAt FROM Users WHERE id = ?', [userId]);

        if (rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json(rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Delete user
app.delete('/api/users/:id', async (req, res) => {
    try {
        const userId = req.params.id;
        
        // Cek admin role
        const [userRow] = await poolPromise.query('SELECT role FROM Users WHERE id = ?', [userId]);
        if (userRow.length > 0 && userRow[0].role === 'admin') {
            return res.status(403).json({ error: 'Cannot delete admin user' });
        }

        // Hapus user (Bookings dengan foreign key mungkin harus dihapus manual atau sudah cascade di DB)
        await poolPromise.query('DELETE FROM Bookings WHERE user_id = ?', [userId]);
        await poolPromise.query('DELETE FROM Users WHERE id = ?', [userId]);
        
        res.json({ message: 'User deleted successfully' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- MOTOR MANAGEMENT ---

app.put('/api/motors/:id', async (req, res) => {
    try {
        const { nama, harga, deskripsi, gambar, status, kategori } = req.body;
        const motorId = req.params.id;
        
        await poolPromise.query(
            'UPDATE Motors SET nama=?, harga=?, deskripsi=?, gambar=?, status=?, kategori=? WHERE id=?',
            [nama, harga, deskripsi, gambar, status, kategori, motorId]
        );
        res.json({ message: 'Motor updated' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/motors', async (req, res) => {
    try {
        const { nama, harga, deskripsi, gambar, kategori } = req.body;
        
        await poolPromise.query(
            'INSERT INTO Motors (nama, harga, deskripsi, gambar, status, kategori) VALUES (?, ?, ?, ?, \'available\', ?)',
            [nama, harga, deskripsi, gambar, kategori]
        );
        res.status(201).json({ message: 'Motor added' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.delete('/api/motors/:id', async (req, res) => {
    try {
        const motorId = req.params.id;
        await poolPromise.query('DELETE FROM Motors WHERE id = ?', [motorId]);
        res.json({ message: 'Motor deleted' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ============================================
// --- OWNER REPORTS ROUTES ---
// ============================================

// Laporan Keuangan (Pendapatan)
app.get('/api/reports/financial', async (req, res) => {
    try {
        // Total pendapatan dari booking yang selesai (done)
        const [totalRevenue] = await poolPromise.query(
            "SELECT COALESCE(SUM(total_harga), 0) as total FROM Bookings WHERE status = 'done'"
        );

        // Pendapatan bulan ini
        const [monthlyRevenue] = await poolPromise.query(
            "SELECT COALESCE(SUM(total_harga), 0) as total FROM Bookings WHERE status = 'done' AND MONTH(created_at) = MONTH(CURRENT_DATE()) AND YEAR(created_at) = YEAR(CURRENT_DATE())"
        );

        // Total DP yang sudah masuk
        const [totalDP] = await poolPromise.query(
            "SELECT COALESCE(SUM(dp_amount), 0) as total FROM Bookings WHERE status_pembayaran IN ('dp_lunas', 'lunas')"
        );

        // Jumlah transaksi per status
        const [statusCount] = await poolPromise.query(
            "SELECT status, COUNT(*) as count FROM Bookings GROUP BY status"
        );

        // Pendapatan per bulan (untuk grafik)
        const [monthlyChart] = await poolPromise.query(
            `SELECT DATE_FORMAT(created_at, '%Y-%m') as bulan, SUM(total_harga) as total 
             FROM Bookings WHERE status = 'done' 
             GROUP BY DATE_FORMAT(created_at, '%Y-%m') 
             ORDER BY bulan DESC LIMIT 12`
        );

        res.json({
            totalRevenue: totalRevenue[0].total,
            monthlyRevenue: monthlyRevenue[0].total,
            totalDP: totalDP[0].total,
            statusCount,
            monthlyChart
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Motor Terlaris
app.get('/api/reports/top-motors', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(
            `SELECT m.nama, m.kategori, m.harga, COUNT(b.id) as total_booking, SUM(b.total_harga) as total_revenue
             FROM Bookings b
             JOIN Motors m ON b.motor_id = m.id
             WHERE b.status NOT IN ('cancelled', 'rejected')
             GROUP BY b.motor_id, m.nama, m.kategori, m.harga
             ORDER BY total_booking DESC
             LIMIT 10`
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Laporan User Aktif
app.get('/api/reports/active-users', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(
            `SELECT u.nama, u.email, COUNT(b.id) as total_booking, SUM(b.total_harga) as total_spent
             FROM Users u
             JOIN Bookings b ON u.id = b.user_id
             WHERE b.status NOT IN ('cancelled', 'rejected')
             GROUP BY u.id, u.nama, u.email
             ORDER BY total_booking DESC
             LIMIT 10`
        );
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- EXPORT ROUTES ---

app.get('/api/export/excel', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(`
            SELECT b.*, u.nama as userName, u.email as userEmail, m.nama as motorNama, m.harga as motorHarga 
            FROM Bookings b 
            LEFT JOIN Users u ON b.user_id = u.id 
            LEFT JOIN Motors m ON b.motor_id = m.id
            ORDER BY b.created_at DESC
        `);
        
        const allData = rows;
        const workbook = new ExcelJS.Workbook();
        
        const createSheet = (sheetName, data) => {
            const sheet = workbook.addWorksheet(sheetName);
            
            // 1. KOP SURAT / HEADER LAPORAN
            sheet.mergeCells('A1', 'I1');
            const mainTitle = sheet.getCell('A1');
            mainTitle.value = 'LAPORAN REKAPITULASI TRANSAKSI NGEBUT.IN';
            mainTitle.font = { name: 'Arial Black', size: 16, bold: true, color: { argb: 'FFFFFFFF' } };
            mainTitle.alignment = { vertical: 'middle', horizontal: 'center' };
            mainTitle.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCC0000' } };

            sheet.mergeCells('A2', 'I2');
            const subTitle = sheet.getCell('A2');
            subTitle.value = `Dicetak pada: ${new Date().toLocaleString('id-ID')}`;
            subTitle.font = { italic: true, size: 10 };
            subTitle.alignment = { horizontal: 'center' };

            sheet.addRow([]);

            // 2. HEADER TABEL
            const headers = ['ID Booking', 'Penyewa', 'Email', 'Motor', 'Tgl Mulai', 'Tgl Selesai', 'Total Bayar', 'Status', 'Waktu Transaksi'];
            const headerRow = sheet.addRow(headers);
            
            headerRow.eachCell((cell) => {
                cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
                cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF333333' } };
                cell.alignment = { horizontal: 'center' };
                cell.border = {
                    top: { style: 'thin' },
                    left: { style: 'thin' },
                    bottom: { style: 'thin' },
                    right: { style: 'thin' }
                };
            });

            // 3. ISI DATA
            data.forEach((b) => {
                const row = sheet.addRow([
                    `#${b.id.toString().slice(-6)}`,
                    b.userName,
                    b.userEmail || '-',
                    b.motorNama,
                    b.tgl_mulai ? new Date(b.tgl_mulai).toISOString().split('T')[0] : '-',
                    b.tgl_selesai ? new Date(b.tgl_selesai).toISOString().split('T')[0] : '-',
                    b.total_harga,
                    (b.status || '').toUpperCase(),
                    b.created_at ? new Date(b.created_at).toLocaleString('id-ID') : '-'
                ]);

                row.eachCell((cell, colNumber) => {
                    cell.border = {
                        top: { style: 'thin' },
                        left: { style: 'thin' },
                        bottom: { style: 'thin' },
                        right: { style: 'thin' }
                    };
                    
                    if (colNumber === 7) {
                        cell.numFmt = '"Rp "#,##0';
                        cell.alignment = { horizontal: 'right' };
                    }
                });
            });

            // 4. AUTO-FIT COLUMNS
            sheet.columns.forEach((column, i) => {
                let maxLength = 0;
                column.eachCell({ includeEmpty: true }, (cell) => {
                    const columnLength = cell.value ? cell.value.toString().length : 10;
                    if (columnLength > maxLength) maxLength = columnLength;
                });
                column.width = maxLength < 10 ? 10 : maxLength + 2;
            });
        };

        // Sheet 1: Semua Transaksi
        createSheet('Semua Transaksi', allData);
        
        // Sheet 2: Transaksi Selesai (DONE)
        const doneData = allData.filter(b => b.status === 'done');
        createSheet('Transaksi Selesai', doneData);

        // Kirim sebagai File Download
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', 'attachment; filename=Laporan_NgebutIN.xlsx');

        await workbook.xlsx.write(res);
        res.end();

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Broadcast Notification
app.post('/api/admin/broadcast', async (req, res) => {
    try {
        const { subject, message } = req.body;
        
        // Ambil semua user
        const [users] = await poolPromise.query('SELECT email, fcm_token FROM Users WHERE role = "user"');
        
        // Kirim Email
        const emails = users.map(u => u.email).filter(e => e);
        if (emails.length > 0) {
            const nodemailer = require('nodemailer');
            const transporter = nodemailer.createTransport({
                service: 'gmail',
                auth: { user: process.env.EMAIL_USER || 'ngebutin.id@gmail.com', pass: process.env.EMAIL_PASS || 'vnhz hgnt qhvy sfhm' }
            });
            const mailOptions = {
                from: '"NgebutIN" <no-reply@ngebut.in>',
                to: emails.join(','),
                subject: subject,
                html: `
                    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; border: 1px solid #ddd; padding: 20px; border-radius: 10px;">
                        <h2 style="color: #CC0000;">Ngebut.in Pengumuman</h2>
                        <p>${message}</p>
                    </div>
                `
            };
            transporter.sendMail(mailOptions).catch(e => console.error("Broadcast email error:", e));
        }

        // Kirim Push Notification
        if (fcmInitialized) {
            const tokens = users.map(u => u.fcm_token).filter(t => t);
            if (tokens.length > 0) {
                const payload = {
                    notification: { title: subject, body: message },
                    tokens: tokens
                };
                admin.messaging().sendMulticast(payload).catch(e => console.error("FCM Broadcast error:", e));
            }
        }

        res.json({ message: 'Broadcast sent successfully!' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = app;
