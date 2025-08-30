const express = require('express');
const next = require('next');
const path = require('path');

const dev = process.env.NODE_ENV !== 'production';
const hostname = 'localhost';
const port = parseInt(process.env.PORT || '3000', 10);

const app = next({ dev, hostname, port });
const handle = app.getRequestHandler();

app.prepare().then(() => {
  const server = express();

  // Servir archivos estáticos
  server.use('/public', express.static(path.join(__dirname, 'public')));

  // Manejar todas las rutas con Next.js
  server.all('*', (req, res) => {
    return handle(req, res);
  });

  server.listen(port, (err) => {
    if (err) throw err;
    console.log(`> Ready on http://${hostname}:${port}`);
    console.log('> Comparty App is running!');
    console.log('> Open your browser and visit: http://localhost:' + port);
  });
}).catch((err) => {
  console.error('Error starting server:', err);
  process.exit(1);
});