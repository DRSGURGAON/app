# UNTESTED in the build environment (no Docker daemon was available) - verify with `docker build .` before relying on it.
FROM node:22-slim AS build
WORKDIR /app
COPY apps/api/package*.json apps/api/
COPY apps/admin/package*.json apps/admin/
RUN cd apps/api && npm ci && cd ../admin && npm ci
COPY apps/api apps/api
COPY apps/admin apps/admin
RUN cd apps/admin && npm run build && cd ../api && npm run build

FROM node:22-slim
ENV NODE_ENV=production PORT=4000 ADMIN_DIST_DIR=/app/admin-dist UPLOAD_DIR=/data/uploads
WORKDIR /app/api
COPY --from=build /app/apps/api/package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/apps/api/dist ./dist
COPY --from=build /app/apps/admin/dist /app/admin-dist
VOLUME /data
EXPOSE 4000
CMD ["node", "dist/server.js"]
