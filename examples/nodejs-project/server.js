// examples/nodejs-project/server.js
// Минимальный Express сервер с health-check endpoint
// Готов к деплою через vps-deploy-kit

const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// ✅ Health-check endpoint — ОБЯЗАТЕЛЕН для автодеплоя
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

app.get('/', (req, res) => {
  res.json({ message: 'Hello from vps-deploy-kit! 🚀' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
