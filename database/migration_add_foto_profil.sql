-- MIGRATION: Tambah kolom foto_profil ke tabel Users
-- Jalankan script ini pada database yang sudah ada

IF NOT EXISTS (
    SELECT * FROM sys.columns
    WHERE object_id = OBJECT_ID(N'Users')
    AND name = 'foto_profil'
)
BEGIN
    ALTER TABLE Users ADD foto_profil NVARCHAR(MAX) NULL;
    PRINT 'Kolom foto_profil berhasil ditambahkan ke tabel Users';
END
ELSE
BEGIN
    PRINT 'Kolom foto_profil sudah ada di tabel Users';
END
GO
