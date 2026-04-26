// API CLIENT FOR NGEBUT.IN
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
            localStorage.setItem('user', JSON.stringify(data.user));
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
        localStorage.removeItem('user');
        window.location.href = '../login.html';
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
        const user = localStorage.getItem('user');
        return user ? JSON.parse(user) : null;
    }
};
