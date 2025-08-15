# --- Build stage ---
  FROM node:20-alpine AS deps
  WORKDIR /app
  
  # ⛔ Remove Corepack to avoid triggering rootless networking
  # RUN corepack enable || true
  
  # Copy ONLY npm manifests to force npm path (no pnpm/yarn detection)
  COPY package.json package-lock.json ./
  
  # Install deps with npm (no Corepack involved)
  RUN npm ci
  
  # Copy the rest and build
  FROM deps AS build
  WORKDIR /app
  COPY . .
  ENV NEXT_TELEMETRY_DISABLED=1
  
  # Force npm build path
  RUN npm run build
  
  # --- Runtime stage (standalone output) ---
  FROM node:20-alpine AS runner
  WORKDIR /app
  ENV NODE_ENV=production
  ENV NEXT_TELEMETRY_DISABLED=1
  
  # Next.js standalone output (Next 13+/App Router supported)
  COPY --from=build /app/.next/standalone ./
  COPY --from=build /app/.next/static ./.next/static
  COPY --from=build /app/public ./public
  
  # Non-root user (exists in node image)
  USER node
  
  # Next server listens on 3000 by default; you’ve chosen 3003
  EXPOSE 3003
  ENV PORT=3003
  
  CMD ["node", "server.js"]