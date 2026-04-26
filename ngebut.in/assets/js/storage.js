// =============================================
// NGEBUT.IN - STORAGE LAYER (INTEGRATED WITH BACKEND)
// =============================================

const API_URL = '/api';

// --- USERS ---
function getUsers() {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', API_URL + '/users', false);
    xhr.send(null);
    if (xhr.status === 200) return JSON.parse(xhr.responseText);
    return [];
}
function saveUsers(data) {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', API_URL + '/users/bulk', false);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(JSON.stringify(data));
}

// --- MOTOR ---
function getMotor() {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', API_URL + '/motors', false);
    xhr.send(null);
    if (xhr.status === 200) return JSON.parse(xhr.responseText);
    return [];
}
function saveMotor(data) {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', API_URL + '/motors/bulk', false);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(JSON.stringify(data));
}

// --- BOOKING ---
function getBooking() {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', API_URL + '/bookings', false);
    xhr.send(null);
    if (xhr.status === 200) return JSON.parse(xhr.responseText);
    return [];
}
function saveBooking(data) {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', API_URL + '/bookings/bulk', false);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(JSON.stringify(data));
}

// --- AUTH ---
function getCurrentUser() {
    return JSON.parse(localStorage.getItem('ngebutin_current_user'));
}
function saveCurrentUser(user) {
    localStorage.setItem('ngebutin_current_user', JSON.stringify(user));
}
function logout() {
    localStorage.removeItem('ngebutin_current_user');
    window.location.href = '../login.html';
}

// --- AUTO SYNC ---
function syncAutoDone() {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', API_URL + '/sync', false);
    xhr.send(null);
}

// Jalankan sync setiap 1 menit
setInterval(syncAutoDone, 60000);