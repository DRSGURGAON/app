import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
// Built with relative asset paths so the API can serve it from /admin. In dev, /v1 and /uploads are proxied to the API.
export default defineConfig({ base: './', plugins: [react()], server: { port: 5173, proxy: { '/v1': 'http://localhost:4000', '/uploads': 'http://localhost:4000' } }, build: { outDir: 'dist', sourcemap: false } });
