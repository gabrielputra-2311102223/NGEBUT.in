const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { sql, poolPromise } = require('./db');

const app = express();
app.use(cors());
app.use(bodyParser.json());

const JWT_SECRET = process.env.JWT_SECRET || 'ngebutin_super_secret_123';

// --- AUTH ROUTES ---

app.post('/api/auth/register', async (req, res) => {
    try {
        const { nama, email, password } = req.body;
        const pool = await poolPromise;
        const hashedPassword = await bcrypt.hash(password, 10);
        
        await pool.request()
            .input('nama', sql.NVarChar, nama)
            .input('email', sql.NVarChar, email)
            .input('password', sql.NVarChar, hashedPassword)
            .query('INSERT INTO Users (nama, email, password, role) VALUES (@nama, @email, @password, \'user\')');
            
        res.status(201).json({ message: 'User registered successfully' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const pool = await poolPromise;
        const result = await pool.request()
            .input('email', sql.NVarChar, email)
            .query('SELECT * FROM Users WHERE email = @email');
            
        const user = result.recordset[0];
        if (!user || !(await bcrypt.compare(password, user.password))) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const token = jwt.sign({ id: user.id, role: user.role, nama: user.nama }, JWT_SECRET, { expiresIn: '1d' });
        res.json({ token, user: { id: user.id, nama: user.nama, role: user.role } });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- MOTOR ROUTES ---

app.get('/api/motors', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT * FROM Motors');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- BOOKING ROUTES ---

app.get('/api/bookings', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query(`
            SELECT b.*, u.nama as userName, u.email as userEmail, m.nama as motorNama, m.harga 
            FROM Bookings b 
            LEFT JOIN Users u ON b.user_id = u.id 
            LEFT JOIN Motors m ON b.motor_id = m.id
            ORDER BY b.created_at DESC
        `);
        // Map to format expected by frontend
        const bookings = result.recordset.map(b => ({
            id: b.id,
            motorId: b.motor_id,
            motorName: b.motorNama,
            userId: b.user_id,
            userName: b.userName,
            userEmail: b.userEmail,
            harga: b.harga,
            totalHarga: b.total_harga,
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

app.post('/api/bookings', async (req, res) => {
    try {
        const { user_id, motor_id, tgl_mulai, tgl_selesai, total_harga } = req.body;
        const pool = await poolPromise;
        
        await pool.request()
            .input('user_id', sql.Int, user_id)
            .input('motor_id', sql.Int, motor_id)
            .input('tgl_mulai', sql.Date, tgl_mulai)
            .input('tgl_selesai', sql.Date, tgl_selesai)
            .input('total_harga', sql.Int, total_harga)
            .query('INSERT INTO Bookings (user_id, motor_id, tgl_mulai, tgl_selesai, total_harga, status) VALUES (@user_id, @motor_id, @tgl_mulai, @tgl_selesai, @total_harga, \'pending\')');
            
        res.status(201).json({ message: 'Booking submitted' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Update booking status (approve/reject)
app.put('/api/bookings/:id/status', async (req, res) => {
    try {
        const { status } = req.body;
        const pool = await poolPromise;
        await pool.request()
            .input('id', sql.Int, req.params.id)
            .input('status', sql.NVarChar, status)
            .query('UPDATE Bookings SET status = @status WHERE id = @id');
        res.json({ message: 'Booking status updated' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- USER ROUTES ---

app.get('/api/users', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query('SELECT id, nama, email, role, created_at as createdAt FROM Users');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- MOTOR MANAGEMENT ---

app.put('/api/motors/:id', async (req, res) => {
    try {
        const { nama, harga, deskripsi, gambar, status, kategori } = req.body;
        const pool = await poolPromise;
        await pool.request()
            .input('id', sql.Int, req.params.id)
            .input('nama', sql.NVarChar, nama)
            .input('harga', sql.Int, harga)
            .input('deskripsi', sql.NVarChar, deskripsi)
            .input('gambar', sql.NVarChar, gambar)
            .input('status', sql.NVarChar, status)
            .input('kategori', sql.NVarChar, kategori)
            .query('UPDATE Motors SET nama=@nama, harga=@harga, deskripsi=@deskripsi, gambar=@gambar, status=@status, kategori=@kategori WHERE id=@id');
        res.json({ message: 'Motor updated' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/motors', async (req, res) => {
    try {
        const { nama, harga, deskripsi, gambar, kategori } = req.body;
        const pool = await poolPromise;
        await pool.request()
            .input('nama', sql.NVarChar, nama)
            .input('harga', sql.Int, harga)
            .input('deskripsi', sql.NVarChar, deskripsi)
            .input('gambar', sql.NVarChar, gambar)
            .input('kategori', sql.NVarChar, kategori)
            .query('INSERT INTO Motors (nama, harga, deskripsi, gambar, status, kategori) VALUES (@nama, @harga, @deskripsi, @gambar, \'available\', @kategori)');
        res.status(201).json({ message: 'Motor added' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.delete('/api/motors/:id', async (req, res) => {
    try {
        const pool = await poolPromise;
        await pool.request()
            .input('id', sql.Int, req.params.id)
            .query('DELETE FROM Motors WHERE id = @id');
        res.json({ message: 'Motor deleted' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = app;
