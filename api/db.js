const mysql = require('mysql2/promise');
require('dotenv').config();

// Create the connection pool
// This uses generic environment variables that can be set in Vercel or locally
const poolPromise = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'ngebutin',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Test the connection immediately
poolPromise.getConnection()
    .then(connection => {
        console.log('Connected to MySQL Database');
        connection.release();
    })
    .catch(err => {
        console.error('Database Connection Failed: ', err);
    });

module.exports = {
    poolPromise
};
