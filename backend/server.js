const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Import error handler
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

// Import routes
const uploadRoutes = require('./routes/upload');
const recordsRoutes = require('./routes/records');
const asksRoutes = require('./routes/asks');
const repliesRoutes = require('./routes/replies');
const likesRoutes = require('./routes/likes');
const usersRoutes = require('./routes/users');

// API v1 Routes
app.use('/api/v1/upload', uploadRoutes);
app.use('/api/v1/records', recordsRoutes);
app.use('/api/v1/asks', asksRoutes);
app.use('/api/v1/replies', repliesRoutes);
app.use('/api/v1/likes', likesRoutes);
app.use('/api/v1/users', usersRoutes);

// Health Check
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok',
    message: 'Raibu Backend API v1',
    version: '3.1',
    endpoints: {
      upload: '/api/v1/upload',
      records: '/api/v1/records',
      asks: '/api/v1/asks',
      replies: '/api/v1/replies',
      likes: '/api/v1/likes',
      users: '/api/v1/users',
    }
  });
});

// 404 Handler
app.use(notFoundHandler);

// Global Error Handler
app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`🚀 Raibu Backend is running on port ${PORT}`);
  console.log(`📍 API Base URL: http://localhost:${PORT}/api/v1`);
});
