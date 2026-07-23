import express from 'express';
import cors from 'cors';

const app = express();

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[API] ${req.method} ${req.originalUrl} - ${res.statusCode} (${duration}ms)`);
  });
  next();
});

// Middleware
app.use(cors());
app.use(express.json());

// Routes
import authRoutes from './features/auth/auth.routes.js';
import wordsRoutes from './features/words/words.routes.js';
import graphRoutes from './features/graph/graph.routes.js';
import socialRoutes from './features/social/social.routes.js';
import notificationsRoutes from './features/notifications/notifications.routes.js';
import adminRoutes from './features/admin/admin.routes.js';

// Basic health check route
app.get('/api/v1/health', (req, res) => {
  res.status(200).json({ success: true, message: 'VocabFlow API is running' });
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/words', wordsRoutes);
app.use('/api/v1/graph', graphRoutes);
app.use('/api/v1/social', socialRoutes);
app.use('/api/v1/notifications', notificationsRoutes);
app.use('/api/v1/admin', adminRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'An unexpected error occurred.',
    },
  });
});

export default app;
