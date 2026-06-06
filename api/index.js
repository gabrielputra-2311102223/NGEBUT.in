const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const ExcelJS = require('exceljs');
const { poolPromise } = require('./db');

const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

const JWT_SECRET = process.env.JWT_SECRET || 'ngebutin_super_secret_123';



// --- AUTH ROUTES ---

app.post('/api/auth/register', async (req, res) => {
    try {
        const { nama, email, password } = req.body;
        const hashedPassword = await bcrypt.hash(password, 10);
        
        const [result] = await poolPromise.query(
            'INSERT INTO Users (nama, email, password, role) VALUES (?, ?, ?, \'user\')',
            [nama, email, hashedPassword]
        );
            
        res.status(201).json({ message: 'User registered successfully', insertId: result.insertId });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

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

        const token = jwt.sign({ id: user.id, role: user.role, nama: user.nama }, JWT_SECRET, { expiresIn: '7d' });
        res.json({ token, user: { id: user.id, nama: user.nama, role: user.role, foto_profil: user.foto_profil } });
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
        
        await poolPromise.query(
            'INSERT INTO Bookings (user_id, motor_id, tgl_mulai, tgl_selesai, total_harga, status) VALUES (?, ?, ?, ?, ?, \'confirm\')',
            [user_id, motor_id, tgl_mulai, tgl_selesai, total_harga]
        );
            
        res.status(201).json({ message: 'Booking submitted' });
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
        await poolPromise.query(
            'UPDATE Bookings SET status = ? WHERE id = ?',
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
        const [rows] = await poolPromise.query('SELECT id, nama, email, role, foto_profil, created_at as createdAt FROM Users');
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Update user profile (for own profile)
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

        // Password change logic
        if (new_password) {
            if (!current_password) {
                return res.status(400).json({ error: 'Current password required to change password' });
            }
            if (!(await bcrypt.compare(current_password, currentUser.password))) {
                return res.status(401).json({ error: 'Current password is incorrect' });
            }
            hashedPassword = await bcrypt.hash(new_password, 10);
        }

        const foto = foto_profil !== undefined ? foto_profil : currentUser.foto_profil;

        await poolPromise.query(
            'UPDATE Users SET nama=?, foto_profil=?, password=? WHERE id=?',
            [nama || currentUser.nama, foto, hashedPassword, userId]
        );

        res.json({ message: 'Profile updated successfully', user: { id: currentUser.id, nama: nama || currentUser.nama, foto_profil: foto } });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Upload profile photo (multipart/form-data alternative via base64)
// This is a convenience endpoint for setting profile photo separately
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
            mainTitle.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCC0000' } }; // Merah Ngebut.in

            sheet.mergeCells('A2', 'I2');
            const subTitle = sheet.getCell('A2');
            subTitle.value = `Dicetak pada: ${new Date().toLocaleString('id-ID')}`;
            subTitle.font = { italic: true, size: 10 };
            subTitle.alignment = { horizontal: 'center' };

            sheet.addRow([]); // Baris kosong

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
                    b.tgl_mulai ? b.tgl_mulai.toISOString().split('T')[0] : '-',
                    b.tgl_selesai ? b.tgl_selesai.toISOString().split('T')[0] : '-',
                    b.total_harga,
                    b.status.toUpperCase(),
                    b.created_at ? b.created_at.toLocaleString('id-ID') : '-'
                ]);

                // Style Baris Data
                row.eachCell((cell, colNumber) => {
                    cell.border = {
                        top: { style: 'thin' },
                        left: { style: 'thin' },
                        bottom: { style: 'thin' },
                        right: { style: 'thin' }
                    };
                    
                    // Format Rupiah untuk kolom Total Bayar (Kolom 7)
                    if (colNumber === 7) {
                        cell.numFmt = '"Rp "#,##0';
                        cell.alignment = { horizontal: 'right' };
                    }
                });
            });

            // 4. AUTO-FIT COLUMNS (Estimasi)
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

module.exports = app;
