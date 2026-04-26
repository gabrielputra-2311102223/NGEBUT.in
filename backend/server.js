const express = require('express');
const cors = require('cors');
const path = require('path');
const apiRoutes = require('./routes/api');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static frontend files
app.use(express.static(path.join(__dirname, '../ngebut.in')));

// API Routes
app.use('/api', apiRoutes);

// Fallback for SPA routing if needed (though this is a static site)
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../ngebut.in/index.html'));
});

// Start Server
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
    console.log(`Frontend is being served statically at http://localhost:${PORT}`);
});
