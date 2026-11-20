FROM node:22-bookworm-slim
WORKDIR /app/backend
COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY backend/src ./src
COPY backend/scripts ./scripts
COPY frontend /app/frontend
COPY database /app/database
USER node
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
CMD ["node", "src/app.js"]
