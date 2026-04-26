// =============================================
// NGEBUT.IN - API CLIENT (PRODUCTION)
// Compatible with all dashboard pages
// =============================================

const API_URL = window.location.origin;

const ApiClient = {
    // Auth
    login: async (email, password) => {
        const res = await fetch(`${API_URL}/api/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });
        const data = await res.json();
        if (data.token) {
            localStorage.setItem('token', data.token);
            localStorage.setItem('ngebutin_current_user', JSON.stringify(data.user));
        }
        return data;
    },

    register: async (nama, email, password) => {
        const res = await fetch(`${API_URL}/api/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ nama, email, password })
        });
        return await res.json();
    },

    logout: () => {
        localStorage.removeItem('token');
        localStorage.removeItem('ngebutin_current_user');
        // Detect if we're in a subfolder (admin/ or user/)
        if (window.location.pathname.includes('/admin/') || window.location.pathname.includes('/user/')) {
            window.location.href = '../login.html';
        } else {
            window.location.href = 'login.html';
        }
    },

    // Motors
    getMotors: async () => {
        const res = await fetch(`${API_URL}/api/motors`);
        return await res.json();
    },

    // Bookings
    createBooking: async (bookingData) => {
        const res = await fetch(`${API_URL}/api/bookings`, {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            body: JSON.stringify(bookingData)
        });
        return await res.json();
    },

    // Helpers
    getCurrentUser: () => {
        const user = localStorage.getItem('ngebutin_current_user');
        return user ? JSON.parse(user) : null;
    }
};

// =============================================
// BACKWARD COMPATIBILITY FUNCTIONS
// These global functions allow old dashboard pages
// (that use storage.js) to work without changes
// =============================================

function getCurrentUser() {
    return ApiClient.getCurrentUser();
}

function saveCurrentUser(user) {
    localStorage.setItem('ngebutin_current_user', JSON.stringify(user));
}

function logout() {
    ApiClient.logout();
}

function getMotor() {
    // Synchronous fallback - fetch motors from API
    const xhr = new XMLHttpRequest();
    xhr.open('GET', API_URL + '/api/motors', false);
    xhr.send(null);
    if (xhr.status === 200) return JSON.parse(xhr.responseText);
    return [];
}

async function addMotor(data) {
    const res = await fetch(API_URL + '/api/motors', {
        method: 'POST',
        headers: { 
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + localStorage.getItem('token')
        },
        body: JSON.stringify(data)
    });
    return res.status === 201;
}

async function updateMotor(id, data) {
    const res = await fetch(API_URL + '/api/motors/' + id, {
        method: 'PUT',
        headers: { 
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + localStorage.getItem('token')
        },
        body: JSON.stringify(data)
    });
    return res.status === 200;
}

async function deleteMotor(id) {
    const res = await fetch(API_URL + '/api/motors/' + id, {
        method: 'DELETE',
        headers: { 
            'Authorization': 'Bearer ' + localStorage.getItem('token')
        }
    });
    return res.status === 200;
}

function saveMotor(data) {
    console.log('saveMotor is deprecated in production mode');
}

function getBooking() {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', API_URL + '/api/bookings', false);
    xhr.setRequestHeader('Authorization', 'Bearer ' + localStorage.getItem('token'));
    xhr.send(null);
    if (xhr.status === 200) return JSON.parse(xhr.responseText);
    return [];
}

function getBookings() {
    return getBooking();
}

function saveBooking(data) {
    console.log('saveBooking is deprecated in production mode');
}

function saveBookings(data) {
    console.log('saveBookings is deprecated in production mode');
}

function getUsers() {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', API_URL + '/api/users', false);
    xhr.setRequestHeader('Authorization', 'Bearer ' + localStorage.getItem('token'));
    xhr.send(null);
    if (xhr.status === 200) return JSON.parse(xhr.responseText);
    return [];
}

function saveUsers(data) {
    console.log('saveUsers is deprecated in production mode');
}

function updateBookingStatus(id, status) {
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', API_URL + '/api/bookings/' + id + '/status', false);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.setRequestHeader('Authorization', 'Bearer ' + localStorage.getItem('token'));
    xhr.send(JSON.stringify({ status }));
    return xhr.status === 200;
}

function checkReturnNotifications(userId) {
    try {
        const bookings = getBooking().filter(b => 
            String(b.userId) === String(userId) && b.status === 'paid'
        );
        const now = new Date();
        now.setHours(0, 0, 0, 0);
        const notifications = [];
        
        bookings.forEach(b => {
            const endDate = new Date(b.endDate);
            endDate.setHours(0, 0, 0, 0);
            const diffTime = endDate - now;
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            if (diffDays < 0) {
                notifications.push({
                    type: 'danger',
                    title: '⚠️ Sewa Terlambat!',
                    message: `Motor ${b.motorName} sudah melewati batas waktu pengembalian.`,
                    icon: 'fa-exclamation-triangle'
                });
            } else if (diffDays === 0) {
                notifications.push({
                    type: 'warning',
                    title: '⏰ Hari Terakhir!',
                    message: `Motor ${b.motorName} harus dikembalikan hari ini.`,
                    icon: 'fa-clock'
                });
            } else if (diffDays === 1) {
                notifications.push({
                    type: 'warning',
                    title: '📅 Besok Pengembalian!',
                    message: `Motor ${b.motorName} harus dikembalikan besok.`,
                    icon: 'fa-calendar-alt'
                });
            }
        });
        return notifications;
    } catch (err) {
        return [];
    }
}

function calculateDays(start, end) {
    const d1 = new Date(start);
    const d2 = new Date(end);
    if (isNaN(d1) || isNaN(d2)) return 0;
    
    // Set to midnight to avoid time diff issues
    d1.setHours(0,0,0,0);
    d2.setHours(0,0,0,0);
    
    const diffTime = d2 - d1;
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
    return diffDays > 0 ? diffDays : 0;
}

function downloadCSV(filename, headers, dataRows, reportTitle = "LAPORAN") {
    // Hitung ringkasan
    const totalTransactions = dataRows.length;
    let totalRevenue = 0;
    dataRows.forEach(row => {
        // Cari angka di kolom total bayar (biasanya index 6 atau 7)
        const amountStr = String(row.find(v => String(v).includes('Rp')) || row[6] || 0);
        const amount = parseFloat(amountStr.replace(/[^\d.-]/g, ''));
        if (!isNaN(amount)) totalRevenue += amount;
    });

    const now = new Date().toLocaleString('id-ID');
    const separator = "==========================================================================";
    
    // Header Laporan Super Premium
    const reportHeader = [
        [separator],
        [`NGEBUT.IN - OFFICIAL TRANSACTION REPORT`],
        [separator],
        [`JENIS LAPORAN : ${reportTitle.toUpperCase()}`],
        [`TANGGAL CETAK : ${now}`],
        [''],
        ['RINGKASAN EKSEKUTIF'],
        ['-'.repeat(30)],
        ['Total Volume Transaksi', `${totalTransactions} Records`],
        ['Total Omzet Bruto', `Rp ${totalRevenue.toLocaleString('id-ID')}`],
        ['-'.repeat(30)],
        [''],
        ['TABEL DATA DETAIL'],
        headers
    ];

    // Footer Laporan
    const reportFooter = [
        [''],
        [separator],
        [`Dokumen ini dihasilkan secara otomatis oleh Sistem Ngebut.in`],
        [`Copyright © 2026 Ngebut.in - Premium Rental Solutions`],
        [separator]
    ];

    // Escape special characters and wrap in quotes
    const processRow = (row) => row.map(val => {
        const cleanVal = (val === null || val === undefined) ? '-' : String(val).replace(/"/g, '""');
        return `"${cleanVal}"`;
    }).join(',');

    const csvContent = [
        ...reportHeader.map(row => row.map(v => `"${v}"`).join(',')),
        ...dataRows.map(processRow),
        ...reportFooter.map(row => row.map(v => `"${v}"`).join(','))
    ].join('\r\n');

    const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

function getMotorImage(gambar) {
    if (!gambar) return 'https://placehold.co/400x300/1A1A1A/white?text=No+Image';
    
    // Jika Base64 (dimulai dengan data:image) atau URL luar (http)
    if (gambar.startsWith('data:image') || gambar.startsWith('http')) {
        return gambar;
    }
    
    // Jika path lokal yang sudah benar
    if (gambar.startsWith('../') || gambar.startsWith('/')) {
        return gambar;
    }
    
    // Jika path lokal relatif (tambahkan ../)
    return '../' + gambar;
}

function formatRupiah(angka) {
    return 'Rp ' + Number(angka).toLocaleString('id-ID');
}

function showNotification(message, type) {
    const notif = document.createElement('div');
    notif.className = `alert alert-${type === 'success' ? 'success' : 'danger'}`;
    notif.style.cssText = `
        position: fixed; top: 20px; right: 20px; z-index: 9999;
        padding: 1rem 1.5rem; border-radius: 8px; color: white;
        font-weight: 600; box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        background: ${type === 'success' ? '#22c55e' : type === 'danger' ? '#ef4444' : '#f59e0b'};
    `;
    notif.innerText = message;
    document.body.appendChild(notif);
    setTimeout(() => notif.remove(), 3000);
}

