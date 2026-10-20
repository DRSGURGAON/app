import 'dotenv/config';
import { createPool } from '../src/db/pool.js';
import { migrate } from '../src/db/migrate.js';

export default async function setup() {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is required for tests');
  if (!/test/.test(url)) throw new Error('Refusing to run tests against a database whose URL does not contain "test"');
  const db = createPool(url, 2);
  await db.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
  await db.query('CREATE EXTENSION IF NOT EXISTS pg_trgm; CREATE EXTENSION IF NOT EXISTS pgcrypto;');
  await migrate(db);
  await db.end();
}
