const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
const pointsRoutes = require('./routes/points');
const imagesRoutes = require('./routes/images');
const interactionsRoutes = require('./routes/interactions');

app.use('/points', pointsRoutes);
app.use('/points', imagesRoutes); // Mounted on /points to match /points/:pointId/images
app.use('/points', interactionsRoutes); // Mounted on /points to match /points/:pointId/like etc.

// Health Check
app.get('/', (req, res) => {
  res.send('Map App Backend is running!');
});

// Error Handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
