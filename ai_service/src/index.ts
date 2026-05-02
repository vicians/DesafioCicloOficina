import 'express-async-errors';
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import aiRoutes from './routes/ai_routes';

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3001;

// Registro das rotas modulares
app.use(aiRoutes);

// Error handler global
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('AI_SERVICE_ERROR:', err.message);
  res.status(500).json({ error: 'Erro interno no processamento de IA.' });
});

app.listen(PORT, () => {
  console.log(`🚀 AI Service da CicloOficina online na porta ${PORT}`);
});
