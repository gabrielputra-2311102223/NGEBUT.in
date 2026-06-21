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
        admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
        fcmInitialized = true;
    }
} catch (e) {
    console.error('Firebase Admin error:', e.message);
}

// ============================================================
// STARTUP: Auto-create/migrate columns & status values
// ============================================================
async function runStartupMigrations() {
    const q = (sql) => poolPromise.query(sql).catch(() => {});
    // Add new columns if not exist
    await q("ALTER TABLE Bookings ADD COLUMN bukti_pelunasan TEXT NULL");
    await q("ALTER TABLE Bookings ADD COLUMN pelunasan_amount INT DEFAULT 0");
    await q("ALTER TABLE Bookings ADD COLUMN catatan_admin TEXT NULL");
    await q("ALTER TABLE Users ADD COLUMN fcm_token VARCHAR(255) NULL");

    // Migrate old status values → new ones
    await q("UPDATE Bookings SET status = 'pending'   WHERE status = 'confirm'");
    await q("UPDATE Bookings SET status = 'confirmed' WHERE status = 'booked'");
    await q("UPDATE Bookings SET status = 'completed' WHERE status = 'done'");
    await q("UPDATE Bookings SET status_pembayaran = 'dp_approved'          WHERE status_pembayaran = 'dp_lunas'");
    await q("UPDATE Bookings SET status_pembayaran = 'menunggu_pelunasan'   WHERE status = 'returning' AND status_pembayaran = 'dp_approved'");
    // Update motor status for confirmed bookings
    await q("UPDATE Motors m INNER JOIN Bookings b ON m.id = b.motor_id SET m.status = 'booked' WHERE b.status IN ('pending','confirmed','returning') AND m.status = 'available'");
    console.log('Startup migrations done.');
}
runStartupMigrations();

// ============================================================
// HELPERS
// ============================================================

// Normalize a booking row to a clean response object
function normalizeBooking(b) {
    return {
        id: b.id,
        motorId: b.motor_id,
        motorName: b.motorName || b.motorNama || `Motor #${b.motor_id}`,
        motorGambar: b.motorGambar || '',
        motorKategori: b.motorKategori || '',
        motorHarga: b.motorHarga || b.harga || 0,
        userId: b.user_id,
        userName: b.userName || `User #${b.user_id}`,
        userEmail: b.userEmail || '',
        totalHarga: b.total_harga || 0,
        dpAmount: b.dp_amount || 0,
        pelunasanAmount: b.pelunasan_amount || (b.total_harga - b.dp_amount) || 0,
        dpBukti: b.dp_bukti || '',
        buktiPelunasan: b.bukti_pelunasan || '',
        statusPembayaran: b.status_pembayaran || 'menunggu_dp',
        startDate: b.tgl_mulai,
        endDate: b.tgl_selesai,
        status: b.status,
        catatanAdmin: b.catatan_admin || '',
        createdAt: b.created_at
    };
}

// ============================================================
// AUTH ROUTES
// ============================================================

app.post('/api/auth/register', async (req, res) => {
    try {
        const { nama, email, password } = req.body;
        const [existing] = await poolPromise.query('SELECT id, email_verified FROM Users WHERE email = ?', [email]);
        if (existing.length > 0) {
            if (existing[0].email_verified) return res.status(400).json({ error: 'Email sudah terdaftar' });
            await poolPromise.query('DELETE FROM Users WHERE email = ? AND email_verified = 0', [email]);
        }
        const hashedPassword = await bcrypt.hash(password, 10);
        const otpCode = generateOTP();
        const otpExpires = new Date(Date.now() + 10 * 60 * 1000);
        await poolPromise.query(
            "INSERT INTO Users (nama, email, password, role, email_verified, otp_code, otp_expires) VALUES (?, ?, ?, 'user', 0, ?, ?)",
            [nama, email, hashedPassword, otpCode, otpExpires]
        );
        try { await sendOtpEmail(email, otpCode); } catch (e) { console.error('OTP email error:', e.message); }
        res.status(201).json({ message: 'OTP telah dikirim ke email Anda', requireOtp: true });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/auth/verify-otp', async (req, res) => {
    try {
        const { email, otp } = req.body;
        const [rows] = await poolPromise.query('SELECT * FROM Users WHERE email = ? AND email_verified = 0', [email]);
        if (rows.length === 0) return res.status(400).json({ error: 'Email tidak ditemukan atau sudah terverifikasi' });
        const user = rows[0];
        if (new Date() > new Date(user.otp_expires)) return res.status(400).json({ error: 'Kode OTP sudah kedaluwarsa. Silakan daftar ulang.' });
        if (user.otp_code !== otp) return res.status(400).json({ error: 'Kode OTP salah' });
        await poolPromise.query('UPDATE Users SET email_verified = 1, otp_code = NULL, otp_expires = NULL WHERE email = ?', [email]);
        res.json({ message: 'Email berhasil diverifikasi! Silakan login.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const [rows] = await poolPromise.query('SELECT * FROM Users WHERE email = ?', [email]);
        const user = rows[0];
        if (!user || !(await bcrypt.compare(password, user.password))) return res.status(401).json({ error: 'Email atau password salah' });
        if (user.role === 'user' && !user.email_verified) return res.status(403).json({ error: 'Email belum diverifikasi. Silakan cek inbox Anda.' });
        const token = jwt.sign({ id: user.id, role: user.role, nama: user.nama }, JWT_SECRET, { expiresIn: '7d' });
        res.json({ token, user: { id: user.id, nama: user.nama, role: user.role, foto_profil: user.foto_profil, email: user.email } });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/auth/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        const [rows] = await poolPromise.query('SELECT * FROM Users WHERE email = ?', [email]);
        if (rows.length === 0) return res.status(404).json({ error: 'Email tidak terdaftar.' });
        const user = rows[0];
        const otpCode = generateOTP();
        const otpExpires = new Date(Date.now() + 10 * 60 * 1000);
        await poolPromise.query('UPDATE Users SET otp_code = ?, otp_expires = ? WHERE email = ?', [otpCode, otpExpires, email]);
        try { await sendResetPasswordOtp(email, otpCode, user.nama); } catch (e) { console.error('Reset OTP email error:', e.message); }
        res.json({ message: 'Kode OTP untuk reset password telah dikirim ke email Anda.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/auth/reset-password', async (req, res) => {
    try {
        const { email, otp, newPassword } = req.body;
        const [rows] = await poolPromise.query('SELECT * FROM Users WHERE email = ?', [email]);
        if (rows.length === 0) return res.status(404).json({ error: 'Email tidak ditemukan.' });
        const user = rows[0];
        if (!user.otp_code || !user.otp_expires || new Date() > new Date(user.otp_expires)) return res.status(400).json({ error: 'Kode OTP sudah tidak valid atau kedaluwarsa.' });
        if (user.otp_code !== otp) return res.status(400).json({ error: 'Kode OTP salah.' });
        const hashedPassword = await bcrypt.hash(newPassword, 10);
        await poolPromise.query('UPDATE Users SET password = ?, otp_code = NULL, otp_expires = NULL WHERE email = ?', [hashedPassword, email]);
        try { await sendPasswordChangeNotification(email, user.nama); } catch (e) {}
        res.json({ message: 'Password berhasil direset! Silakan login.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ============================================================
// MOTOR ROUTES
// ============================================================

app.get('/api/motors', async (req, res) => {
    try {
        const [rows] = await poolPromise.query('SELECT * FROM Motors ORDER BY id DESC');
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/motors', async (req, res) => {
    try {
        const { nama, harga, deskripsi, gambar, kategori } = req.body;
        await poolPromise.query(
            "INSERT INTO Motors (nama, harga, deskripsi, gambar, status, kategori) VALUES (?, ?, ?, ?, 'available', ?)",
            [nama, harga, deskripsi, gambar, kategori || 'Matic']
        );
        const [inserted] = await poolPromise.query('SELECT LAST_INSERT_ID() as id');
        res.status(201).json({ message: 'Motor berhasil ditambahkan', id: inserted[0].id });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/motors/:id', async (req, res) => {
    try {
        const { nama, harga, deskripsi, gambar, status, kategori } = req.body;
        const motorId = req.params.id;
        const fields = [];
        const vals = [];
        if (nama !== undefined) { fields.push('nama=?'); vals.push(nama); }
        if (harga !== undefined) { fields.push('harga=?'); vals.push(harga); }
        if (deskripsi !== undefined) { fields.push('deskripsi=?'); vals.push(deskripsi); }
        if (gambar !== undefined && gambar !== '') { fields.push('gambar=?'); vals.push(gambar); }
        if (status !== undefined) { fields.push('status=?'); vals.push(status); }
        if (kategori !== undefined) { fields.push('kategori=?'); vals.push(kategori); }
        if (fields.length === 0) return res.status(400).json({ error: 'Tidak ada data untuk diupdate' });
        vals.push(motorId);
        await poolPromise.query(`UPDATE Motors SET ${fields.join(',')} WHERE id=?`, vals);
        res.json({ message: 'Motor berhasil diupdate' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/motors/:id', async (req, res) => {
    try {
        await poolPromise.query('DELETE FROM Motors WHERE id = ?', [req.params.id]);
        res.json({ message: 'Motor berhasil dihapus' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Check motor availability for date range
app.get('/api/motors/:id/availability', async (req, res) => {
    try {
        const { start, end } = req.query;
        const motorId = req.params.id;
        if (!start || !end) return res.status(400).json({ error: 'Parameter start dan end diperlukan' });
        const [conflicts] = await poolPromise.query(
            `SELECT id FROM Bookings
             WHERE motor_id = ? AND status NOT IN ('cancelled','rejected','completed')
             AND tgl_mulai <= ? AND tgl_selesai >= ?`,
            [motorId, end, start]
        );
        res.json({ available: conflicts.length === 0, conflicts: conflicts.length });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ============================================================
// BOOKING ROUTES
// ============================================================

const BOOKING_JOIN = `
    SELECT b.*, 
        u.nama as userName, u.email as userEmail, 
        m.nama as motorName, m.gambar as motorGambar, 
        m.kategori as motorKategori, m.harga as motorHarga
    FROM Bookings b
    LEFT JOIN Users u ON b.user_id = u.id
    LEFT JOIN Motors m ON b.motor_id = m.id
`;

// GET all bookings (admin/owner)
app.get('/api/bookings', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(BOOKING_JOIN + ' ORDER BY b.created_at DESC');
        res.json(rows.map(normalizeBooking));
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET bookings for a specific user
app.get('/api/bookings/my/:userId', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(
            BOOKING_JOIN + ' WHERE b.user_id = ? ORDER BY b.created_at DESC',
            [req.params.userId]
        );
        res.json(rows.map(normalizeBooking));
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// GET single booking
app.get('/api/bookings/:id', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(BOOKING_JOIN + ' WHERE b.id = ?', [req.params.id]);
        if (rows.length === 0) return res.status(404).json({ error: 'Booking tidak ditemukan' });
        res.json(normalizeBooking(rows[0]));
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// CREATE booking
app.post('/api/bookings', async (req, res) => {
    try {
        const { user_id, motor_id, tgl_mulai, tgl_selesai, total_harga } = req.body;
        if (!user_id || !motor_id || !tgl_mulai || !tgl_selesai || !total_harga) {
            return res.status(400).json({ error: 'Semua field wajib diisi' });
        }

        // Cek ketersediaan motor pada tanggal tersebut
        const [conflicts] = await poolPromise.query(
            `SELECT id FROM Bookings 
             WHERE motor_id = ? AND status NOT IN ('cancelled','rejected','completed')
             AND tgl_mulai <= ? AND tgl_selesai >= ?`,
            [motor_id, tgl_selesai, tgl_mulai]
        );
        if (conflicts.length > 0) {
            return res.status(409).json({ error: 'Motor sudah dipesan pada tanggal tersebut. Silakan pilih tanggal lain.' });
        }

        // Hitung DP 50% dan pelunasan 50%
        const dpAmount = Math.ceil(total_harga * 0.5);
        const pelunasanAmount = total_harga - dpAmount;

        const [result] = await poolPromise.query(
            `INSERT INTO Bookings (user_id, motor_id, tgl_mulai, tgl_selesai, total_harga, dp_amount, pelunasan_amount, status, status_pembayaran)
             VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', 'menunggu_dp')`,
            [user_id, motor_id, tgl_mulai, tgl_selesai, total_harga, dpAmount, pelunasanAmount]
        );
        const bookingId = result.insertId;

        // Kirim notifikasi booking
        try {
            const [userRows] = await poolPromise.query('SELECT nama, email FROM Users WHERE id = ?', [user_id]);
            const [motorRows] = await poolPromise.query('SELECT nama FROM Motors WHERE id = ?', [motor_id]);
            if (userRows.length && motorRows.length) {
                sendBookingNotification(userRows[0].email, userRows[0].nama, motorRows[0].nama, total_harga, dpAmount).catch(console.error);
            }
        } catch (e) {}

        res.status(201).json({
            message: 'Booking berhasil dibuat. Silakan upload bukti pembayaran DP.',
            bookingId,
            dpAmount,
            pelunasanAmount
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// USER: Upload bukti DP
app.put('/api/bookings/:id/upload-dp', async (req, res) => {
    try {
        const { dp_bukti } = req.body;
        if (!dp_bukti) return res.status(400).json({ error: 'Bukti DP diperlukan' });
        await poolPromise.query(
            "UPDATE Bookings SET dp_bukti = ?, status_pembayaran = 'dp_uploaded' WHERE id = ?",
            [dp_bukti, req.params.id]
        );
        res.json({ message: 'Bukti DP berhasil diupload. Menunggu verifikasi admin.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Backward compat: old /dp endpoint
app.put('/api/bookings/:id/dp', async (req, res) => {
    try {
        const { dp_bukti } = req.body;
        if (!dp_bukti) return res.status(400).json({ error: 'Bukti DP diperlukan' });
        await poolPromise.query(
            "UPDATE Bookings SET dp_bukti = ?, status_pembayaran = 'dp_uploaded' WHERE id = ?",
            [dp_bukti, req.params.id]
        );
        res.json({ message: 'Bukti DP berhasil diupload. Menunggu verifikasi admin.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ADMIN: Approve DP → Motor aktif disewa
app.put('/api/bookings/:id/approve-dp', async (req, res) => {
    try {
        const bookingId = req.params.id;
        const [bookingRows] = await poolPromise.query('SELECT motor_id FROM Bookings WHERE id = ?', [bookingId]);
        if (bookingRows.length === 0) return res.status(404).json({ error: 'Booking tidak ditemukan' });

        await poolPromise.query(
            "UPDATE Bookings SET status = 'confirmed', status_pembayaran = 'dp_approved' WHERE id = ?",
            [bookingId]
        );
        // Motor tetap booked selama disewa
        await poolPromise.query("UPDATE Motors SET status = 'booked' WHERE id = ?", [bookingRows[0].motor_id]);

        res.json({ message: 'DP diverifikasi! Motor sekarang aktif disewa.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ADMIN: Reject DP → Booking ditolak, motor tersedia kembali
app.put('/api/bookings/:id/reject-dp', async (req, res) => {
    try {
        const bookingId = req.params.id;
        const { catatan_admin } = req.body;
        const [bookingRows] = await poolPromise.query('SELECT motor_id FROM Bookings WHERE id = ?', [bookingId]);
        if (bookingRows.length === 0) return res.status(404).json({ error: 'Booking tidak ditemukan' });

        await poolPromise.query(
            "UPDATE Bookings SET status = 'rejected', status_pembayaran = 'dp_ditolak', catatan_admin = ? WHERE id = ?",
            [catatan_admin || 'DP tidak valid', bookingId]
        );
        await poolPromise.query("UPDATE Motors SET status = 'available' WHERE id = ?", [bookingRows[0].motor_id]);

        res.json({ message: 'Booking ditolak. Motor kembali tersedia.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ADMIN: Konfirmasi motor dikembalikan → tunggu pelunasan
app.put('/api/bookings/:id/return', async (req, res) => {
    try {
        const bookingId = req.params.id;
        await poolPromise.query(
            "UPDATE Bookings SET status = 'returning', status_pembayaran = 'menunggu_pelunasan' WHERE id = ?",
            [bookingId]
        );
        // Motor sudah kembali tapi belum available (tunggu pelunasan)
        res.json({ message: 'Motor dikonfirmasi kembali. Menunggu pembayaran pelunasan.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// USER: Upload bukti pelunasan
app.put('/api/bookings/:id/upload-pelunasan', async (req, res) => {
    try {
        const { bukti_pelunasan } = req.body;
        if (!bukti_pelunasan) return res.status(400).json({ error: 'Bukti pelunasan diperlukan' });
        await poolPromise.query(
            "UPDATE Bookings SET bukti_pelunasan = ?, status_pembayaran = 'pelunasan_uploaded' WHERE id = ?",
            [bukti_pelunasan, req.params.id]
        );
        res.json({ message: 'Bukti pelunasan berhasil diupload. Menunggu verifikasi admin.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ADMIN: Approve pelunasan → Selesai, motor tersedia kembali
app.put('/api/bookings/:id/approve-pelunasan', async (req, res) => {
    try {
        const bookingId = req.params.id;
        const [bookingRows] = await poolPromise.query('SELECT motor_id FROM Bookings WHERE id = ?', [bookingId]);
        if (bookingRows.length === 0) return res.status(404).json({ error: 'Booking tidak ditemukan' });

        await poolPromise.query(
            "UPDATE Bookings SET status = 'completed', status_pembayaran = 'lunas' WHERE id = ?",
            [bookingId]
        );
        await poolPromise.query("UPDATE Motors SET status = 'available' WHERE id = ?", [bookingRows[0].motor_id]);

        res.json({ message: 'Pelunasan dikonfirmasi! Sewa selesai. Motor kembali tersedia.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ADMIN: Selesaikan tanpa bukti (bayar tunai di toko)
app.put('/api/bookings/:id/complete-cash', async (req, res) => {
    try {
        const bookingId = req.params.id;
        const [bookingRows] = await poolPromise.query('SELECT motor_id FROM Bookings WHERE id = ?', [bookingId]);
        if (bookingRows.length === 0) return res.status(404).json({ error: 'Booking tidak ditemukan' });

        await poolPromise.query(
            "UPDATE Bookings SET status = 'completed', status_pembayaran = 'lunas', catatan_admin = 'Pelunasan tunai di tempat' WHERE id = ?",
            [bookingId]
        );
        await poolPromise.query("UPDATE Motors SET status = 'available' WHERE id = ?", [bookingRows[0].motor_id]);

        res.json({ message: 'Sewa selesai dengan pelunasan tunai.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// USER/ADMIN: Cancel booking
app.put('/api/bookings/:id/cancel', async (req, res) => {
    try {
        const bookingId = req.params.id;
        const { catatan_admin } = req.body;
        const [bookingRows] = await poolPromise.query('SELECT motor_id, status FROM Bookings WHERE id = ?', [bookingId]);
        if (bookingRows.length === 0) return res.status(404).json({ error: 'Booking tidak ditemukan' });

        await poolPromise.query(
            "UPDATE Bookings SET status = 'cancelled', status_pembayaran = 'dibatalkan', catatan_admin = ? WHERE id = ?",
            [catatan_admin || 'Dibatalkan', bookingId]
        );
        // Hanya bebaskan motor jika booking belum confirmed (pending)
        if (['pending'].includes(bookingRows[0].status)) {
            await poolPromise.query("UPDATE Motors SET status = 'available' WHERE id = ?", [bookingRows[0].motor_id]);
        }
        res.json({ message: 'Booking berhasil dibatalkan.' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Legacy: general status update (backward compat)
app.put('/api/bookings/:id/status', async (req, res) => {
    try {
        let { status } = req.body;
        const bookingId = req.params.id;

        // Map old status values to new ones
        const statusMap = { confirm: 'pending', booked: 'confirmed', done: 'completed' };
        status = statusMap[status] || status;

        const [bookingRows] = await poolPromise.query('SELECT motor_id FROM Bookings WHERE id = ?', [bookingId]);
        const motorId = bookingRows[0]?.motor_id;

        let extraSQL = '';
        if (status === 'completed') extraSQL = ", status_pembayaran = 'lunas'";
        if (status === 'cancelled' || status === 'rejected') extraSQL = ", status_pembayaran = 'dibatalkan'";

        await poolPromise.query(`UPDATE Bookings SET status = ?${extraSQL} WHERE id = ?`, [status, bookingId]);

        if (motorId) {
            let motorStatus = 'available';
            if (['confirmed', 'returning'].includes(status)) motorStatus = 'booked';
            await poolPromise.query('UPDATE Motors SET status = ? WHERE id = ?', [motorStatus, motorId]);
        }

        res.json({ message: 'Status booking diperbarui' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ============================================================
// USER ROUTES
// ============================================================

app.get('/api/users', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(
            'SELECT id, nama, email, role, foto_profil, email_verified, created_at as createdAt FROM Users ORDER BY created_at DESC'
        );
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/users/me/:id', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(
            'SELECT id, nama, email, role, foto_profil, created_at as createdAt FROM Users WHERE id = ?',
            [req.params.id]
        );
        if (rows.length === 0) return res.status(404).json({ error: 'User tidak ditemukan' });
        res.json(rows[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/users/:id', async (req, res) => {
    try {
        const { nama, email, foto_profil, current_password, new_password } = req.body;
        const userId = req.params.id;
        const [userRows] = await poolPromise.query('SELECT * FROM Users WHERE id = ?', [userId]);
        if (userRows.length === 0) return res.status(404).json({ error: 'User tidak ditemukan' });

        const currentUser = userRows[0];
        let hashedPassword = currentUser.password;
        let passwordChanged = false;

        if (new_password) {
            if (!current_password) return res.status(400).json({ error: 'Password lama diperlukan' });
            if (!(await bcrypt.compare(current_password, currentUser.password))) return res.status(401).json({ error: 'Password lama salah' });
            hashedPassword = await bcrypt.hash(new_password, 10);
            passwordChanged = true;
        }

        let finalEmail = currentUser.email;
        if (email && email !== currentUser.email) {
            const [emailCheck] = await poolPromise.query('SELECT id FROM Users WHERE email = ? AND id != ?', [email, userId]);
            if (emailCheck.length > 0) return res.status(400).json({ error: 'Email sudah digunakan oleh akun lain' });
            finalEmail = email;
        }

        const foto = foto_profil !== undefined ? foto_profil : currentUser.foto_profil;
        await poolPromise.query('UPDATE Users SET nama=?, email=?, foto_profil=?, password=? WHERE id=?',
            [nama || currentUser.nama, finalEmail, foto, hashedPassword, userId]);

        if (passwordChanged) {
            try { await sendPasswordChangeNotification(finalEmail, nama || currentUser.nama); } catch (e) {}
        }

        res.json({ message: 'Profil berhasil diperbarui', user: { id: currentUser.id, nama: nama || currentUser.nama, email: finalEmail, foto_profil: foto } });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.put('/api/users/:id/fcm-token', async (req, res) => {
    try {
        await poolPromise.query('UPDATE Users SET fcm_token = ? WHERE id = ?', [req.body.fcm_token, req.params.id]);
        res.json({ message: 'FCM Token updated' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/users/:id/photo', async (req, res) => {
    try {
        const { photo } = req.body;
        if (!photo) return res.status(400).json({ error: 'Photo data diperlukan' });
        await poolPromise.query('UPDATE Users SET foto_profil=? WHERE id=?', [photo, req.params.id]);
        res.json({ message: 'Foto profil berhasil diupdate', foto_profil: photo });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/users/:id', async (req, res) => {
    try {
        const [userRow] = await poolPromise.query('SELECT role FROM Users WHERE id = ?', [req.params.id]);
        if (userRow.length > 0 && userRow[0].role === 'admin') return res.status(403).json({ error: 'Tidak dapat menghapus akun admin' });
        await poolPromise.query('DELETE FROM Bookings WHERE user_id = ?', [req.params.id]);
        await poolPromise.query('DELETE FROM Users WHERE id = ?', [req.params.id]);
        res.json({ message: 'User berhasil dihapus' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ============================================================
// OWNER REPORT ROUTES
// ============================================================

app.get('/api/reports/financial', async (req, res) => {
    try {
        const [totalRevenue] = await poolPromise.query(
            "SELECT COALESCE(SUM(total_harga), 0) as total FROM Bookings WHERE status = 'completed'"
        );
        const [monthlyRevenue] = await poolPromise.query(
            "SELECT COALESCE(SUM(total_harga), 0) as total FROM Bookings WHERE status = 'completed' AND MONTH(created_at) = MONTH(CURRENT_DATE()) AND YEAR(created_at) = YEAR(CURRENT_DATE())"
        );
        const [totalDP] = await poolPromise.query(
            "SELECT COALESCE(SUM(dp_amount), 0) as total FROM Bookings WHERE status_pembayaran IN ('dp_approved','menunggu_pelunasan','pelunasan_uploaded','lunas')"
        );
        const [statusCount] = await poolPromise.query("SELECT status, COUNT(*) as count FROM Bookings GROUP BY status");
        const [monthlyChart] = await poolPromise.query(
            `SELECT DATE_FORMAT(created_at, '%Y-%m') as bulan, SUM(total_harga) as total
             FROM Bookings WHERE status = 'completed'
             GROUP BY DATE_FORMAT(created_at, '%Y-%m')
             ORDER BY bulan DESC LIMIT 12`
        );
        res.json({ totalRevenue: totalRevenue[0].total, monthlyRevenue: monthlyRevenue[0].total, totalDP: totalDP[0].total, statusCount, monthlyChart });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/reports/top-motors', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(
            `SELECT m.nama, m.kategori, m.harga, COUNT(b.id) as total_booking, SUM(b.total_harga) as total_revenue
             FROM Bookings b JOIN Motors m ON b.motor_id = m.id
             WHERE b.status NOT IN ('cancelled','rejected')
             GROUP BY b.motor_id, m.nama, m.kategori, m.harga
             ORDER BY total_booking DESC LIMIT 10`
        );
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/reports/active-users', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(
            `SELECT u.nama, u.email, COUNT(b.id) as total_booking, SUM(b.total_harga) as total_spent
             FROM Users u JOIN Bookings b ON u.id = b.user_id
             WHERE b.status NOT IN ('cancelled','rejected')
             GROUP BY u.id, u.nama, u.email
             ORDER BY total_booking DESC LIMIT 10`
        );
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ============================================================
// EXPORT ROUTES
// ============================================================

app.get('/api/export/excel', async (req, res) => {
    try {
        const [rows] = await poolPromise.query(`
            SELECT b.*, u.nama as userName, u.email as userEmail, m.nama as motorNama, m.harga as motorHarga
            FROM Bookings b
            LEFT JOIN Users u ON b.user_id = u.id
            LEFT JOIN Motors m ON b.motor_id = m.id
            ORDER BY b.created_at DESC
        `);

        const workbook = new ExcelJS.Workbook();

        const createSheet = (sheetName, data) => {
            const sheet = workbook.addWorksheet(sheetName);
            sheet.mergeCells('A1', 'J1');
            const mainTitle = sheet.getCell('A1');
            mainTitle.value = 'LAPORAN REKAPITULASI TRANSAKSI NGEBUT.IN';
            mainTitle.font = { name: 'Arial Black', size: 16, bold: true, color: { argb: 'FFFFFFFF' } };
            mainTitle.alignment = { vertical: 'middle', horizontal: 'center' };
            mainTitle.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCC0000' } };
            sheet.getRow(1).height = 30;

            sheet.mergeCells('A2', 'J2');
            const subTitle = sheet.getCell('A2');
            subTitle.value = `Dicetak pada: ${new Date().toLocaleString('id-ID')}`;
            subTitle.font = { italic: true, size: 10 };
            subTitle.alignment = { horizontal: 'center' };
            sheet.addRow([]);

            const headers = ['ID', 'Penyewa', 'Email', 'Motor', 'Tgl Mulai', 'Tgl Selesai', 'Total', 'DP', 'Pelunasan', 'Status'];
            const headerRow = sheet.addRow(headers);
            headerRow.eachCell((cell) => {
                cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
                cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF333333' } };
                cell.alignment = { horizontal: 'center' };
                cell.border = { top: { style: 'thin' }, left: { style: 'thin' }, bottom: { style: 'thin' }, right: { style: 'thin' } };
            });

            data.forEach((b) => {
                const row = sheet.addRow([
                    `#${String(b.id).slice(-6)}`,
                    b.userName, b.userEmail || '-', b.motorNama,
                    b.tgl_mulai ? new Date(b.tgl_mulai).toISOString().split('T')[0] : '-',
                    b.tgl_selesai ? new Date(b.tgl_selesai).toISOString().split('T')[0] : '-',
                    b.total_harga, b.dp_amount, b.pelunasan_amount || (b.total_harga - b.dp_amount),
                    (b.status || '').toUpperCase()
                ]);
                row.eachCell((cell, col) => {
                    cell.border = { top: { style: 'thin' }, left: { style: 'thin' }, bottom: { style: 'thin' }, right: { style: 'thin' } };
                    if ([7, 8, 9].includes(col)) { cell.numFmt = '"Rp "#,##0'; cell.alignment = { horizontal: 'right' }; }
                });
            });

            sheet.columns.forEach((col) => {
                let max = 10;
                col.eachCell({ includeEmpty: true }, (cell) => {
                    const len = cell.value ? cell.value.toString().length : 10;
                    if (len > max) max = len;
                });
                col.width = max + 2;
            });
        };

        createSheet('Semua Transaksi', rows);
        createSheet('Selesai', rows.filter(b => b.status === 'completed'));
        createSheet('Aktif', rows.filter(b => ['pending', 'confirmed', 'returning'].includes(b.status)));

        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', 'attachment; filename=Laporan_NgebutIN.xlsx');
        await workbook.xlsx.write(res);
        res.end();
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ============================================================
// BROADCAST NOTIFICATION
// ============================================================

app.post('/api/admin/broadcast', async (req, res) => {
    try {
        const { subject, message } = req.body;
        const [users] = await poolPromise.query('SELECT email, fcm_token FROM Users WHERE role = "user"');
        const emails = users.map(u => u.email).filter(e => e);
        if (emails.length > 0) {
            const nodemailer = require('nodemailer');
            const transporter = nodemailer.createTransport({
                service: 'gmail',
                auth: { user: process.env.EMAIL_USER || 'ngebutin.id@gmail.com', pass: process.env.EMAIL_PASS || 'vnhz hgnt qhvy sfhm' }
            });
            transporter.sendMail({
                from: '"NgebutIN" <no-reply@ngebut.in>',
                to: emails.join(','),
                subject,
                html: `<div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border:1px solid #ddd;padding:20px;border-radius:10px;"><h2 style="color:#CC0000;">Ngebut.in Pengumuman</h2><p>${message}</p></div>`
            }).catch(e => console.error('Broadcast email error:', e));
        }
        if (fcmInitialized) {
            const tokens = users.map(u => u.fcm_token).filter(t => t);
            if (tokens.length > 0) {
                admin.messaging().sendMulticast({ notification: { title: subject, body: message }, tokens }).catch(e => console.error('FCM error:', e));
            }
        }
        res.json({ message: 'Broadcast berhasil dikirim!' });
    } catch (err) { res.status(500).json({ error: err.message }); }
});


// ============================================================
// KWITANSI HTML PAGE (printable in browser)
// ============================================================

app.get('/api/kwitansi/:bookingId', async (req, res) => {
    try {
        const { bookingId } = req.params;
        const [rows] = await poolPromise.query(`
            SELECT b.id, b.tgl_mulai, b.tgl_selesai, b.total_harga, b.dp_amount, b.status,
                   u.nama as userName, u.email as userEmail,
                   m.nama as motorNama, m.kategori as motorKategori, m.harga as motorHarga
            FROM Bookings b
            LEFT JOIN Users u ON b.user_id = u.id
            LEFT JOIN Motors m ON b.motor_id = m.id
            WHERE b.id = ?
        `, [bookingId]);
        if (!rows.length) return res.status(404).send('<h1>Booking tidak ditemukan</h1>');

        const b = rows[0];
        const total = parseInt(b.total_harga) || 0;
        const dp = parseInt(b.dp_amount) || Math.floor(total / 2);
        const pelunasan = total - dp;
        const start = b.tgl_mulai ? new Date(b.tgl_mulai) : null;
        const end = b.tgl_selesai ? new Date(b.tgl_selesai) : null;
        const days = (start && end) ? Math.abs(Math.ceil((end - start) / (1000*60*60*24))) + 1 : 1;
        const hargaPerHari = days > 0 ? Math.floor(total / days) : b.motorHarga || 0;
        const fmt = (n) => 'Rp ' + parseInt(n).toLocaleString('id-ID');
        const fmtDate = (d) => d ? new Date(d).toLocaleDateString('id-ID', {day:'2-digit',month:'long',year:'numeric'}) : '-';
        const noTrx = '#' + String(b.id).padStart(6, '0');
        const now = new Date().toLocaleDateString('id-ID', {day:'2-digit',month:'long',year:'numeric'});

        const html = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kwitansi ${noTrx} - NGEBUT.IN</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:Arial,sans-serif;background:#f3f4f6;min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:20px}
  .card{background:#fff;border-radius:16px;overflow:hidden;width:100%;max-width:480px;box-shadow:0 4px 24px rgba(0,0,0,.12)}
  .hd{background:#CC0000;color:#fff;padding:28px 24px;text-align:center}
  .hd h1{font-size:28px;letter-spacing:3px;font-weight:900;margin-bottom:4px}
  .hd p{font-size:11px;opacity:.8;letter-spacing:2px;text-transform:uppercase}
  .no-trx{display:inline-block;background:rgba(255,255,255,.2);border-radius:8px;padding:6px 20px;margin-top:12px;font-weight:700;font-size:15px;letter-spacing:1px}
  .bd{padding:24px}
  .row{display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid #f3f4f6;font-size:13px}
  .row:last-child{border:none}
  .lbl{color:#6b7280}
  .val{font-weight:600;color:#111}
  .val.r{color:#CC0000;font-size:16px;font-weight:800}
  .val.g{color:#059669;font-weight:700}
  .val.b{color:#1E40AF;font-weight:700}
  .sep{border:none;border-top:2px dashed #e5e7eb;margin:10px 0}
  .lunas{background:#DCFCE7;color:#166534;text-align:center;padding:14px;border-radius:12px;font-size:18px;font-weight:900;letter-spacing:2px;margin:16px 0}
  .ft{background:#f9fafb;padding:14px;text-align:center;font-size:11px;color:#9ca3af;line-height:1.8}
  .btn{display:block;width:100%;padding:14px;background:#CC0000;color:#fff;border:none;border-radius:12px;font-size:15px;font-weight:700;cursor:pointer;margin:16px 0 0;letter-spacing:.5px}
  .btn:hover{background:#aa0000}
  @media print{.btn{display:none}body{background:#fff;padding:0}.card{box-shadow:none;border-radius:0}}
</style>
</head>
<body>
<div class="card">
  <div class="hd">
    <img src="https://ngebut-in.vercel.app/assets/img/logo.png" alt="NGEBUT.IN" style="height:56px;margin-bottom:10px;object-fit:contain;filter:brightness(0) invert(1);" onerror="this.style.display='none';document.getElementById('logoFallback').style.display='block'"/>
    <div id="logoFallback" style="display:none;font-size:28px;margin-bottom:8px">🏍️</div>
    <h1>NGEBUT.IN</h1>
    <p>Kwitansi Resmi Sewa Motor</p>
    <span class="no-trx">${noTrx}</span>
  </div>
  <div class="bd">
    <div class="row"><span class="lbl">Penyewa</span><span class="val">${b.userName || '-'}</span></div>
    <div class="row"><span class="lbl">Email</span><span class="val">${b.userEmail || '-'}</span></div>
    <div class="row"><span class="lbl">Motor</span><span class="val">${b.motorNama || '-'}</span></div>
    <div class="row"><span class="lbl">Kategori</span><span class="val">${b.motorKategori || '-'}</span></div>
    <hr class="sep">
    <div class="row"><span class="lbl">Tanggal Sewa</span><span class="val">${fmtDate(b.tgl_mulai)}</span></div>
    <div class="row"><span class="lbl">Tanggal Kembali</span><span class="val">${fmtDate(b.tgl_selesai)}</span></div>
    <div class="row"><span class="lbl">Durasi</span><span class="val">${days} Hari</span></div>
    <div class="row"><span class="lbl">Harga/Hari</span><span class="val">${fmt(hargaPerHari)}</span></div>
    <hr class="sep">
    <div class="row"><span class="lbl">Total Sewa</span><span class="val r">${fmt(total)}</span></div>
    <div class="row"><span class="lbl">DP Dibayar (50%)</span><span class="val g">${fmt(dp)}</span></div>
    <div class="row"><span class="lbl">Pelunasan (50%)</span><span class="val b">${fmt(pelunasan)}</span></div>
    <hr class="sep">
    <div class="row"><span class="lbl">Tanggal Cetak</span><span class="val">${now}</span></div>
    <div class="lunas">✅ &nbsp;LUNAS</div>
  </div>
  <div class="ft">
    Terima kasih telah menggunakan layanan <strong>Ngebut.in</strong><br>
    Dokumen ini merupakan bukti transaksi yang sah.<br>
    © 2025 Ngebut.in · Layanan Rental Motor Terpercaya
  </div>
  <div style="padding:0 20px 20px">
    <button class="btn" onclick="window.print()">🖨️ &nbsp;Cetak / Simpan PDF</button>
  </div>
</div>
</body>
</html>`;

        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.send(html);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// ============================================================

app.get('/api/cron/check-expiring', async (req, res) => {
    try {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const tomorrowStr = tomorrow.toISOString().split('T')[0];

        const [bookings] = await poolPromise.query(`
            SELECT b.id, b.tgl_selesai, b.status,
                   u.nama as userName, u.email as userEmail,
                   m.nama as motorNama
            FROM Bookings b
            LEFT JOIN Users u ON b.user_id = u.id
            LEFT JOIN Motors m ON b.motor_id = m.id
            WHERE DATE(b.tgl_selesai) = ? AND b.status IN ('confirmed', 'pending')
        `, [tomorrowStr]);

        let sent = 0;
        for (const b of bookings) {
            if (!b.userEmail) continue;
            try {
                const nodemailer = require('nodemailer');
                const transporter = nodemailer.createTransport({
                    service: 'gmail',
                    auth: { user: process.env.EMAIL_USER || 'ngebutin.id@gmail.com', pass: process.env.EMAIL_PASS || 'vnhz hgnt qhvy sfhm' }
                });
                await transporter.sendMail({
                    from: '"NgebutIN 🏍️" <no-reply@ngebut.in>',
                    to: b.userEmail,
                    subject: '⏰ Pengingat: Masa Sewa Motor Anda Berakhir Besok!',
                    html: `
                    <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border-radius:12px;overflow:hidden;border:1px solid #e5e7eb;">
                        <div style="background:#CC0000;padding:24px;text-align:center;">
                            <h1 style="color:#fff;font-size:24px;margin:0;letter-spacing:2px">🏍️ NGEBUT.IN</h1>
                            <p style="color:rgba(255,255,255,0.85);margin:6px 0 0;font-size:13px">Pengingat Masa Sewa</p>
                        </div>
                        <div style="padding:28px 24px;">
                            <p style="font-size:16px">Halo, <strong>${b.userName}</strong>! 👋</p>
                            <p style="color:#374151;margin-top:12px">
                                Masa sewa motor <strong style="color:#CC0000">${b.motorNama}</strong> kamu akan berakhir
                                <strong>besok, ${tomorrowStr}</strong>.
                            </p>
                            <div style="background:#FEF9C3;border-left:4px solid #D97706;padding:14px 16px;border-radius:6px;margin:20px 0;">
                                ⚠️ <strong>Segera kembalikan motor</strong> tepat waktu untuk menghindari biaya keterlambatan.
                            </div>
                            <p style="color:#6b7280;font-size:13px">
                                Jika kamu ingin memperpanjang masa sewa, hubungi kami melalui aplikasi Ngebut.in.
                            </p>
                            <div style="text-align:center;margin-top:24px">
                                <a href="https://ngebut-in.vercel.app" style="background:#CC0000;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600">Buka Aplikasi</a>
                            </div>
                        </div>
                        <div style="background:#f9fafb;padding:14px;text-align:center;font-size:11px;color:#9ca3af">
                            © 2025 Ngebut.in · Layanan Rental Motor Terpercaya
                        </div>
                    </div>`
                });
                sent++;
            } catch (emailErr) {
                console.error(`Email gagal ke ${b.userEmail}:`, emailErr.message);
            }
        }
        res.json({ message: `Notifikasi terkirim ke ${sent} dari ${bookings.length} penyewa.`, date: tomorrowStr });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = app;
