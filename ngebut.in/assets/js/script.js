// =============================================
// NGEBUT.IN - MAIN SCRIPT
// =============================================

// Format currency
function formatRupiah(amount) {
    return 'Rp ' + Number(amount).toLocaleString('id-ID');
}

// Format date
function formatDate(dateString) {
    if (!dateString) return '-';
    const d = new Date(dateString);
    return d.toLocaleDateString('id-ID', { 
        weekday: 'short', 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric' 
    });
}

function formatShortDate(dateString) {
    if (!dateString) return '-';
    const d = new Date(dateString);
    return d.toLocaleDateString('id-ID');
}

// Calculate rental days
function calculateDays(startDate, endDate) {
    const d1 = new Date(startDate);
    const d2 = new Date(endDate);
    if (isNaN(d1) || isNaN(d2)) return 0;
    
    d1.setHours(0,0,0,0);
    d2.setHours(0,0,0,0);
    
    const diffTime = d2 - d1;
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
    return diffDays > 0 ? diffDays : 0;
}

// Get status badge HTML
function getStatusBadge(status) {
    const badges = {
        'confirm': '<span class="status-badge status-confirm"><i class="fas fa-clock"></i> Menunggu Approval</span>',
        'booked': '<span class="status-badge status-booked"><i class="fas fa-motorcycle"></i> Sedang Disewa</span>',
        'paid': '<span class="status-badge status-paid"><i class="fas fa-check-circle"></i> Lunas</span>',
        'returning': '<span class="status-badge status-warning"><i class="fas fa-undo"></i> Menunggu Dicek</span>',
        'done': '<span class="status-badge status-done"><i class="fas fa-flag-checkered"></i> Selesai</span>',
        'cancelled': '<span class="status-badge status-cancelled"><i class="fas fa-times-circle"></i> Dibatalkan</span>'
    };
    return badges[status] || status;
}

function checkReturnNotifications(userId) {
    const bookings = getBooking().filter(b => 
        String(b.userId) === String(userId) && 
        b.status === 'paid' // ✅ HANYA YANG SUDAH LUNAS
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
        } 
        else if (diffDays === 0) {
            notifications.push({
                type: 'warning',
                title: '⏰ Hari Terakhir!',
                message: `Motor ${b.motorName} harus dikembalikan hari ini.`,
                icon: 'fa-clock'
            });
        } 
        else if (diffDays === 1) {
            notifications.push({
                type: 'warning',
                title: '📅 Besok Pengembalian!',
                message: `Motor ${b.motorName} harus dikembalikan besok (${formatShortDate(b.endDate)}).`,
                icon: 'fa-calendar-alt'
            });
        }
    });
    
    return notifications;
}

// Auto update status (placeholder for now)
function syncAutoDone() {
    // Logic to auto-complete bookings can be added here
}

// =============================================
// PROFILE PHOTO (DP) HELPERS
// =============================================

// Get profile photo URL or null if not set
function getProfilePhoto(foto_profil) {
    if (!foto_profil) return null;
    if (foto_profil.startsWith('data:image') || foto_profil.startsWith('http')) {
        return foto_profil;
    }
    return foto_profil;
}

// Get initials from name (for default avatar)
function getInitials(name) {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/);
    if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
    return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
}

// Generate background color for avatar based on name
function getAvatarColor(name) {
    if (!name) return '#cc0000';
    const colors = [
        '#cc0000', '#dc2626', '#ef4444', '#f59e0b', '#10b981',
        '#3b82f6', '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16'
    ];
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
        hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    return colors[Math.abs(hash) % colors.length];
}

// Render avatar (image or initials) into an element
function renderAvatar(target, name, foto_profil, size) {
    const photo = getProfilePhoto(foto_profil);
    const fontSize = (size || 50) * 0.4;
    const el = (typeof target === 'string') ? document.querySelector(target) : target;
    if (!el) return;
    if (photo) {
        el.style.backgroundImage = `url('${photo}')`;
        el.style.backgroundSize = 'cover';
        el.style.backgroundPosition = 'center';
        el.style.color = 'transparent';
        el.innerText = '';
    } else {
        el.style.backgroundImage = 'none';
        el.style.background = getAvatarColor(name);
        el.style.color = 'white';
        el.style.fontSize = fontSize + 'px';
        el.innerText = getInitials(name);
    }
}

// Sidebar toggle logic for mobile
document.addEventListener('DOMContentLoaded', () => {
    const sidebarToggle = document.getElementById('sidebarToggle');
    const sidebar = document.querySelector('.sidebar');
    const overlay = document.getElementById('sidebarOverlay');

    if (sidebarToggle && sidebar && overlay) {
        sidebarToggle.addEventListener('click', () => {
            sidebar.classList.toggle('active');
            overlay.classList.toggle('active');
        });

        overlay.addEventListener('click', () => {
            sidebar.classList.remove('active');
            overlay.classList.remove('active');
        });
    }
});