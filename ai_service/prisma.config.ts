import * as dotenv from 'dotenv';
dotenv.config(); // Carrega o seu .env

import { defineConfig } from '@prisma/config';

export default defineConfig({
  datasource: {
    url: process.env.DATABASE_URL,
  },
});