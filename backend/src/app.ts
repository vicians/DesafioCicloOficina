import 'express-async-errors';
import express from 'express';
import cors from 'cors';

const app = express();

app.use(cors());
app.use(express.json());

// Routes placeholder
app.get('/', (req, res) => {
  return res.json({ message: 'Tião app is running' });
});

export { app };
