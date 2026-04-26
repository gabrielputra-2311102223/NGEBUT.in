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

function saveMotor(data) {
    // Not used in production (admin manages via API)
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

function checkReturnNotifications(userId) {
    // Placeholder - returns empty for now
    return [];
}

function formatRupiah(angka) {
    return 'Rp ' + Number(angka).toLocaleString('id-ID');
}
