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

if (process.env.NODE_ENV !== 'production') {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
}

app.use(routes);

app.use('/whatsapp', webhookRoutes);

export { app };
