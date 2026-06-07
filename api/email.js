const nodemailer = require('nodemailer');
require('dotenv').config();

// Konfigurasi SMTP Gmail
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS  // App Password, bukan password biasa
    }
});

// Generate OTP 6 angka
function generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

// Kirim Email OTP Verifikasi
async function sendOtpEmail(toEmail, otpCode) {
    const mailOptions = {
        from: `"Ngebut.in 🏍️" <${process.env.EMAIL_USER}>`,
        to: toEmail,
        subject: '🔐 Kode Verifikasi OTP - Ngebut.in',
        html: `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 30px; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 20px;">
            <div style="text-align: center; margin-bottom: 25px;">
                <h1 style="color: #e63946; font-size: 28px; margin: 0;">NGEBUT.IN</h1>
                <p style="color: #a0a0b0; font-size: 14px; margin: 5px 0;">Premium Motor Rental</p>
            </div>
            <div style="background: rgba(255,255,255,0.05); border-radius: 15px; padding: 25px; text-align: center; border: 1px solid rgba(255,255,255,0.1);">
                <p style="color: #e0e0e0; font-size: 16px; margin: 0 0 15px;">Kode verifikasi OTP Anda:</p>
                <div style="background: linear-gradient(135deg, #e63946, #ff6b6b); color: white; font-size: 36px; font-weight: bold; letter-spacing: 10px; padding: 20px; border-radius: 12px; margin: 15px 0;">
                    ${otpCode}
                </div>
                <p style="color: #a0a0b0; font-size: 13px; margin: 15px 0 0;">Kode ini berlaku selama <strong style="color: #e63946;">10 menit</strong></p>
                <p style="color: #a0a0b0; font-size: 12px;">Jangan bagikan kode ini kepada siapapun.</p>
            </div>
            <p style="color: #555; font-size: 11px; text-align: center; margin-top: 20px;">© 2026 Ngebut.in - Purwokerto</p>
        </div>
        `
    };

    return transporter.sendMail(mailOptions);
}

// Kirim Email Notifikasi Ganti Password
async function sendPasswordChangeNotification(toEmail, userName) {
    const mailOptions = {
        from: `"Ngebut.in 🏍️" <${process.env.EMAIL_USER}>`,
        to: toEmail,
        subject: '🔒 Password Anda Telah Diubah - Ngebut.in',
        html: `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 30px; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 20px;">
            <div style="text-align: center; margin-bottom: 25px;">
                <h1 style="color: #e63946; font-size: 28px; margin: 0;">NGEBUT.IN</h1>
                <p style="color: #a0a0b0; font-size: 14px; margin: 5px 0;">Premium Motor Rental</p>
            </div>
            <div style="background: rgba(255,255,255,0.05); border-radius: 15px; padding: 25px; border: 1px solid rgba(255,255,255,0.1);">
                <h2 style="color: #e0e0e0; font-size: 18px; margin: 0 0 10px;">Halo, ${userName}! 👋</h2>
                <p style="color: #b0b0c0; font-size: 14px; line-height: 1.7;">
                    Password akun Ngebut.in Anda telah <strong style="color: #22c55e;">berhasil diubah</strong> pada:
                </p>
                <div style="background: rgba(34,197,94,0.1); border: 1px solid rgba(34,197,94,0.3); border-radius: 10px; padding: 12px; text-align: center; margin: 15px 0;">
                    <p style="color: #22c55e; font-weight: bold; margin: 0; font-size: 14px;">
                        📅 ${new Date().toLocaleString('id-ID', { dateStyle: 'full', timeStyle: 'short' })}
                    </p>
                </div>
                <p style="color: #b0b0c0; font-size: 13px; line-height: 1.6;">
                    Jika Anda <strong style="color: #e63946;">TIDAK</strong> melakukan perubahan ini, segera hubungi tim support kami.
                </p>
            </div>
            <p style="color: #555; font-size: 11px; text-align: center; margin-top: 20px;">© 2026 Ngebut.in - Purwokerto</p>
        </div>
        `
    };

    return transporter.sendMail(mailOptions);
}

// Kirim Email Notifikasi Booking / DP
async function sendBookingNotification(toEmail, userName, motorName, totalHarga, dpAmount) {
    const mailOptions = {
        from: `"Ngebut.in 🏍️" <${process.env.EMAIL_USER}>`,
        to: toEmail,
        subject: '📋 Pemesanan Baru - Ngebut.in',
        html: `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 30px; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 20px;">
            <div style="text-align: center; margin-bottom: 25px;">
                <h1 style="color: #e63946; font-size: 28px; margin: 0;">NGEBUT.IN</h1>
            </div>
            <div style="background: rgba(255,255,255,0.05); border-radius: 15px; padding: 25px; border: 1px solid rgba(255,255,255,0.1);">
                <h2 style="color: #e0e0e0; font-size: 18px; margin: 0 0 15px;">Pemesanan Berhasil! 🎉</h2>
                <p style="color: #b0b0c0; font-size: 14px;">Halo <strong style="color: white;">${userName}</strong>,</p>
                <table style="width: 100%; color: #b0b0c0; font-size: 14px; margin: 15px 0;">
                    <tr><td style="padding: 8px 0;">Motor</td><td style="text-align: right; color: white; font-weight: bold;">${motorName}</td></tr>
                    <tr><td style="padding: 8px 0;">Total Harga</td><td style="text-align: right; color: white;">Rp ${Number(totalHarga).toLocaleString('id-ID')}</td></tr>
                    <tr><td style="padding: 8px 0; border-top: 1px solid rgba(255,255,255,0.1);">DP (50%)</td><td style="text-align: right; color: #e63946; font-weight: bold; border-top: 1px solid rgba(255,255,255,0.1);">Rp ${Number(dpAmount).toLocaleString('id-ID')}</td></tr>
                </table>
                <div style="background: rgba(230,57,70,0.15); border: 1px solid rgba(230,57,70,0.3); border-radius: 10px; padding: 12px; text-align: center; margin-top: 10px;">
                    <p style="color: #ff6b6b; font-size: 13px; margin: 0;">⚠️ Silakan bayar DP dan upload bukti pembayaran di Dashboard Anda</p>
                </div>
            </div>
            <p style="color: #555; font-size: 11px; text-align: center; margin-top: 20px;">© 2026 Ngebut.in - Purwokerto</p>
        </div>
        `
    };

    return transporter.sendMail(mailOptions);
}

// Kirim Email OTP Reset Password
async function sendResetPasswordOtp(toEmail, otpCode, userName) {
    const mailOptions = {
        from: `"Ngebut.in 🏍️" <${process.env.EMAIL_USER}>`,
        to: toEmail,
        subject: '🔑 Reset Password - Ngebut.in',
        html: `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 30px; background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%); border-radius: 20px;">
            <div style="text-align: center; margin-bottom: 25px;">
                <h1 style="color: #e63946; font-size: 28px; margin: 0;">NGEBUT.IN</h1>
                <p style="color: #a0a0b0; font-size: 14px; margin: 5px 0;">Premium Motor Rental</p>
            </div>
            <div style="background: rgba(255,255,255,0.05); border-radius: 15px; padding: 25px; text-align: center; border: 1px solid rgba(255,255,255,0.1);">
                <h2 style="color: #e0e0e0; font-size: 18px; margin: 0 0 10px;">Halo, ${userName}!</h2>
                <p style="color: #b0b0c0; font-size: 14px; margin: 0 0 15px;">Kami menerima permintaan untuk mereset password Anda. Berikut adalah kode OTP Anda:</p>
                <div style="background: linear-gradient(135deg, #e63946, #ff6b6b); color: white; font-size: 36px; font-weight: bold; letter-spacing: 10px; padding: 20px; border-radius: 12px; margin: 15px 0;">
                    ${otpCode}
                </div>
                <p style="color: #a0a0b0; font-size: 13px; margin: 15px 0 0;">Kode ini berlaku selama <strong style="color: #e63946;">10 menit</strong></p>
                <p style="color: #a0a0b0; font-size: 12px;">Jika Anda tidak merasa meminta reset password, abaikan email ini.</p>
            </div>
            <p style="color: #555; font-size: 11px; text-align: center; margin-top: 20px;">© 2026 Ngebut.in - Purwokerto</p>
        </div>
        `
    };

    return transporter.sendMail(mailOptions);
}

module.exports = { generateOTP, sendOtpEmail, sendPasswordChangeNotification, sendBookingNotification, sendResetPasswordOtp };
