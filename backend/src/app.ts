import 'express-async-errors';
import express from 'express';
import cors from 'cors';
import routes from './routes';
import webhookRoutes from './webhook';
import swaggerUi from 'swagger-ui-express';
import { swaggerSpec } from './config/swagger';

const app = express();

app.use(cors());
app.use(express.json());

// Middleware para normalizar barras duplas na URL geradas pelo Proxy Reverso do Gateway
app.use((req, res, next) => {
  if (req.url.startsWith('//')) {
    req.url = req.url.replace(/^\/+/, '/');
  }
  next();
});

if (process.env.NODE_ENV !== 'production') {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
}

app.use(routes);

app.use('/whatsapp', webhookRoutes);

export { app };
