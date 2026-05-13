import { Pool } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

let pool: Pool | null = null;

export const getDb = (): Pool => {
    if (pool) {
        return pool;
    }

    pool = new Pool({
        connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/oficina',
    });

    return pool;
};
