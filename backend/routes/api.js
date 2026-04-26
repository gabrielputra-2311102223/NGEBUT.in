const express = require('express');
const router = express.Router();
const db = require('../database');
const crypto = require('crypto');

function hashPassword(password) {
    return crypto.createHash('sha256').update(password).digest('hex');
}

// ==========================================
// AUTH & USERS
// ==========================================

router.post('/auth/login', (req, res) => {
    const { email, password } = req.body;
    const hashedPassword = hashPassword(password);
    db.get(`SELECT * FROM users WHERE email = ? AND password = ?`, [email, hashedPassword], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });
        if (!row) return res.status(401).json({ error: 'Email atau password salah' });
        res.json(row);
    });
});

router.post('/auth/register', (req, res) => {
    const { nama, email, password } = req.body;
    const hashedPassword = hashPassword(password);
    db.run(`INSERT INTO users (nama, email, password) VALUES (?, ?, ?)`, [nama, email, hashedPassword], function(err) {
        if (err) return res.status(400).json({ error: 'Email sudah terdaftar atau terjadi kesalahan' });
        
        db.get(`SELECT * FROM users WHERE id = ?`, [this.lastID], (err, row) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(row);
        });
    });
});

router.post('/users/bulk', (req, res) => {
    db.serialize(() => {
        db.run(`DELETE FROM users WHERE email != 'admin@gmail.com'`);
        const stmt = db.prepare(`INSERT INTO users (id, nama, email, password, role, no_telp, nik, sim, alamat, jk) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
        req.body.forEach(u => {
            if (u.email !== 'admin@gmail.com') {
                stmt.run([u.id, u.nama, u.email, u.password, u.role || 'user', u.no_telp, u.nik, u.sim, u.alamat, u.jk]);
            }
        });
        stmt.finalize();
        res.json({ success: true });
    });
});

router.get('/users', (req, res) => {
    db.all(`SELECT * FROM users`, [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

router.put('/users/:id', (req, res) => {
    const { nama, no_telp, nik, sim, alamat, jk } = req.body;
    db.run(
        `UPDATE users SET nama = ?, no_telp = ?, nik = ?, sim = ?, alamat = ?, jk = ? WHERE id = ?`,
        [nama, no_telp, nik, sim, alamat, jk, req.params.id],
        function(err) {
            if (err) return res.status(500).json({ error: err.message });
            
            db.get(`SELECT * FROM users WHERE id = ?`, [req.params.id], (err, row) => {
                if (err) return res.status(500).json({ error: err.message });
                res.json(row);
            });
        }
    );
});

// ==========================================
// MOTORS
// ==========================================

router.get('/motors', (req, res) => {
    db.all(`SELECT * FROM motors`, [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

router.post('/motors', (req, res) => {
    const { nama, harga, desc, gambar, status } = req.body;
    db.run(
        `INSERT INTO motors (nama, harga, desc, gambar, status) VALUES (?, ?, ?, ?, ?)`,
        [nama, harga, desc, gambar, status],
        function(err) {
            if (err) return res.status(500).json({ error: err.message });
            db.get(`SELECT * FROM motors WHERE id = ?`, [this.lastID], (err, row) => {
                res.json(row);
            });
        }
    );
});

router.post('/motors/bulk', (req, res) => {
    db.serialize(() => {
        db.run(`DELETE FROM motors`);
        const stmt = db.prepare(`INSERT INTO motors (id, nama, harga, desc, gambar, status) VALUES (?, ?, ?, ?, ?, ?)`);
        req.body.forEach(m => {
            stmt.run([m.id, m.nama, m.harga, m.desc, m.gambar, m.status]);
        });
        stmt.finalize();
        res.json({ success: true });
    });
});

router.put('/motors/:id', (req, res) => {
    const { nama, harga, desc, gambar, status } = req.body;
    db.run(
        `UPDATE motors SET nama = ?, harga = ?, desc = ?, gambar = ?, status = ? WHERE id = ?`,
        [nama, harga, desc, gambar, status, req.params.id],
        function(err) {
            if (err) return res.status(500).json({ error: err.message });
            db.get(`SELECT * FROM motors WHERE id = ?`, [req.params.id], (err, row) => {
                res.json(row);
            });
        }
    );
});

router.delete('/motors/:id', (req, res) => {
    db.run(`DELETE FROM motors WHERE id = ?`, [req.params.id], function(err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Motor deleted', id: req.params.id });
    });
});

// ==========================================
// BOOKINGS
// ==========================================

router.get('/bookings', (req, res) => {
    db.all(`SELECT * FROM bookings ORDER BY createdAt DESC`, [], (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

router.post('/bookings', (req, res) => {
    const { id, motorId, motorName, userId, userName, harga, totalHarga, startDate, endDate, status, createdAt } = req.body;
    
    db.run(
        `INSERT INTO bookings (id, motorId, motorName, userId, userName, harga, totalHarga, startDate, endDate, status, createdAt) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [id, motorId, motorName, userId, userName, harga, totalHarga, startDate, endDate, status || 'confirm', createdAt],
        function(err) {
            if (err) return res.status(500).json({ error: err.message });
            
            // If booked, update motor status
            if (status === 'booked' || status === 'paid') {
                db.run(`UPDATE motors SET status = 'booked' WHERE id = ?`, [motorId]);
            }
            
            db.get(`SELECT * FROM bookings WHERE id = ?`, [id], (err, row) => {
                res.json(row);
            });
        }
    );
});

router.post('/bookings/bulk', (req, res) => {
    db.serialize(() => {
        db.run(`DELETE FROM bookings`);
        const stmt = db.prepare(`INSERT INTO bookings (id, motorId, motorName, userId, userName, harga, totalHarga, startDate, endDate, status, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
        req.body.forEach(b => {
            stmt.run([b.id, b.motorId, b.motorName, b.userId, b.userName, b.harga, b.totalHarga, b.startDate, b.endDate, b.status, b.createdAt]);
        });
        stmt.finalize();
        res.json({ success: true });
    });
});

router.put('/bookings/:id', (req, res) => {
    const { status, motorId } = req.body; // Usually we just update status
    
    // First get current booking
    db.get(`SELECT * FROM bookings WHERE id = ?`, [req.params.id], (err, booking) => {
        if (err || !booking) return res.status(404).json({ error: 'Booking not found' });
        
        db.run(
            `UPDATE bookings SET status = ? WHERE id = ?`,
            [status, req.params.id],
            function(err) {
                if (err) return res.status(500).json({ error: err.message });
                
                // Update motor status based on booking status
                if (status === 'done' || status === 'cancelled' || status === 'rejected') {
                    db.run(`UPDATE motors SET status = 'available' WHERE id = ?`, [booking.motorId]);
                } else if (status === 'booked' || status === 'paid') {
                    db.run(`UPDATE motors SET status = 'booked' WHERE id = ?`, [booking.motorId]);
                }
                
                db.get(`SELECT * FROM bookings WHERE id = ?`, [req.params.id], (err, row) => {
                    res.json(row);
                });
            }
        );
    });
});

router.delete('/bookings/:id', (req, res) => {
    db.run(`DELETE FROM bookings WHERE id = ?`, [req.params.id], function(err) {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: 'Booking deleted', id: req.params.id });
    });
});

router.post('/sync', (req, res) => {
    // Auto sync logic ported from frontend
    db.all(`SELECT * FROM bookings`, [], (err, bookings) => {
        if (err) return res.json({ success: false });
        
        db.all(`SELECT * FROM motors`, [], (err, motors) => {
            if (err) return res.json({ success: false });
            
            const now = new Date();
            now.setHours(0, 0, 0, 0);
            
            db.serialize(() => {
                bookings.forEach(b => {
                    if (b.status === 'paid' || b.status === 'booked') {
                        const endDate = new Date(b.endDate);
                        endDate.setHours(0, 0, 0, 0);
                        
                        if (now > endDate) {
                            const motor = motors.find(m => m.id === b.motorId);
                            if (motor && motor.status === 'booked') {
                                db.run(`UPDATE motors SET status = 'available' WHERE id = ?`, [motor.id]);
                            }
                            if (b.status !== 'done') {
                                db.run(`UPDATE bookings SET status = 'done' WHERE id = ?`, [b.id]);
                            }
                        }
                    }
                });
                res.json({ success: true });
            });
        });
    });
});

module.exports = router;
