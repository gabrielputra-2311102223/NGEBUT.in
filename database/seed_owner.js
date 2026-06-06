// =============================================
// SEED OWNER ACCOUNT
// Jalankan: node database/seed_owner.js
// =============================================

require('dotenv').config();
const bcrypt = require('bcryptjs');
const { sql, poolPromise } = require('../api/db');

async function seedOwner() {
    try {
        const pool = await poolPromise;

        // Hash password
        const hashedPassword = await bcrypt.hash('owner123', 10);

        // Check if owner exists
        const checkResult = await pool.request()
            .input('email', sql.NVarChar, 'owner@ngebut.in')
            .query('SELECT id, role FROM Users WHERE email = @email');

        if (checkResult.recordset.length === 0) {
            // Create owner
            await pool.request()
                .input('nama', sql.NVarChar, 'Owner Ngebut.in')
                .input('email', sql.NVarChar, 'owner@ngebut.in')
                .input('password', sql.NVarChar, hashedPassword)
                .query("INSERT INTO Users (nama, email, password, role) VALUES (@nama, @email, @password, 'owner')");

            console.log('✅ Akun owner berhasil dibuat!');
        } else {
            // Update existing to owner
            await pool.request()
                .input('id', sql.Int, checkResult.recordset[0].id)
                .input('password', sql.NVarChar, hashedPassword)
                .query("UPDATE Users SET role = 'owner', password = @password WHERE id = @id");

            console.log('✅ Akun owner@ngebut.in sudah ada, role diupdate ke owner dan password direset');
        }

        console.log('\n📧 Email: owner@ngebut.in');
        console.log('🔑 Password: owner123');
        console.log('\nGunakan kredensial ini untuk login sebagai owner.');

        process.exit(0);
    } catch (err) {
        console.error('❌ Error:', err.message);
        process.exit(1);
    }
}

seedOwner();
