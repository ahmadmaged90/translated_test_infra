const express = require('express');
const mysql = require('mysql2/promise');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
const port = process.env.PORT || 3000;

// Database configuration
const mysqlConfig = {
  host: process.env.MYSQL_HOST,
  port: process.env.MYSQL_PORT,
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE
};

const pgConfig = {
  host: process.env.POSTGRES_HOST,
  port: process.env.POSTGRES_PORT,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DATABASE
};

// Redis configuration
const redisConfig = {
  url: process.env.REDIS_URL || `redis://${process.env.REDIS_HOST}:${process.env.REDIS_PORT}`
};

// Function to redact password from connection string
function redactPassword(str) {
  return str.replace(/(:.*@)/g, ':****@');
}

app.get('/', async (req, res) => {
  let mysqlConnection, pgPool, redisClient;
  const result = {
    message: 'Echo server is running!',
    mysql: {
      connected: 'not configured',
      connectionInfo: 'not configured'
    },
    postgres: {
      connected: 'not configured',
      connectionInfo: 'not configured'
    },
    redis: {
      connected: 'not configured',
      connectionInfo: 'not configured'
    }
  };

  try {
    // MySQL connection check
    if (mysqlConfig.host && mysqlConfig.user && mysqlConfig.password && mysqlConfig.database) {
      result.mysql.connectionInfo = redactPassword(`mysql://${mysqlConfig.user}:${mysqlConfig.password}@${mysqlConfig.host}:${mysqlConfig.port}/${mysqlConfig.database}`);
      try {
        mysqlConnection = await mysql.createConnection(mysqlConfig);
        const [mysqlRows] = await mysqlConnection.execute('SELECT 1 as connected');
        result.mysql.connected = mysqlRows[0].connected === 1;
      } catch (error) {
        console.error('MySQL connection error:', error);
        result.mysql.connected = false;
      }
    }

    // PostgreSQL connection check
    if (pgConfig.host && pgConfig.user && pgConfig.password && pgConfig.database) {
      result.postgres.connectionInfo = redactPassword(`postgresql://${pgConfig.user}:${pgConfig.password}@${pgConfig.host}:${pgConfig.port}/${pgConfig.database}`);
      try {
        pgPool = new Pool(pgConfig);
        const pgRes = await pgPool.query('SELECT 1 as connected');
        result.postgres.connected = pgRes.rows[0].connected === 1;
      } catch (error) {
        console.error('PostgreSQL connection error:', error);
        result.postgres.connected = false;
      }
    }

    // Redis connection check
    if (redisConfig.url) {
      result.redis.connectionInfo = redactPassword(redisConfig.url);
      try {
        redisClient = redis.createClient(redisConfig);
        await redisClient.connect();
        await redisClient.set('testKey', 'Connected to Redis');
        const redisValue = await redisClient.get('testKey');
        result.redis.connected = redisValue === 'Connected to Redis';
      } catch (error) {
        console.error('Redis connection error:', error);
        result.redis.connected = false;
      }
    }

    res.json(result);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    if (mysqlConnection) await mysqlConnection.end();
    if (pgPool) await pgPool.end();
    if (redisClient) await redisClient.quit();
  }
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});