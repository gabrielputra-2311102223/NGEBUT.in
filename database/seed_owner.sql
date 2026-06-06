-- SEED: Akun Owner default
-- Password: owner123 (sudah di-hash dengan bcrypt)
-- Email: owner@ngebut.in
-- Jalankan script ini untuk membuat akun owner pertama

IF NOT EXISTS (SELECT * FROM Users WHERE email = 'owner@ngebut.in')
BEGIN
    INSERT INTO Users (nama, email, password, role, foto_profil)
    VALUES (
        'Owner Ngebut.in',
        'owner@ngebut.in',
        '$2a$10$8K1p/a0dRTlj0Eqox/E6L.7cGfHJcLBYJqLZbqMQqJYzGfXJqJZ.C',
        'owner',
        NULL
    );
    PRINT 'Akun owner berhasil dibuat: owner@ngebut.in / owner123';
END
ELSE
BEGIN
    UPDATE Users SET role = 'owner' WHERE email = 'owner@ngebut.in';
    PRINT 'Akun owner@ngebut.in sudah ada, role diupdate ke owner';
END
GO
