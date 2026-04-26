const sql = require('mssql');
require('dotenv').config();

const config = {
    user: process.env.AZURE_SQL_USER,
    password: process.env.AZURE_SQL_PASSWORD,
    server: process.env.AZURE_SQL_SERVER, 
    database: process.env.AZURE_SQL_DATABASE,
    options: {
        encrypt: true,
        trustServerCertificate: false
    },
    connectionTimeout: 60000,  // 60 detik (default 15 detik terlalu cepat)
    requestTimeout: 30000,     // 30 detik untuk query
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};

const poolPromise = new sql.ConnectionPool(config)
    .connect()
    .then(pool => {
        console.log('Connected to Azure SQL Database');
        return pool;
    })
    .catch(err => {
        console.error('Database Connection Failed: ', err);
        throw err;
    });

module.exports = {
    sql, poolPromise
};
