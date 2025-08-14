# --- Build stage ---
FROM node:20-alpine AS deps
WORKDIR /app
# Enable corepack for pnpm/yarn if you use them; otherwise npm is fine
RUN corepack enable || true

# Copy only package manifests first (better cache)
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
# Install deps (auto-detect your lockfile)
RUN \
  if [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile; \
  elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
  else npm ci; fi

# Copy the rest and build
FROM deps AS build
WORKDIR /app
COPY . .
# Set NEXT_TELEMETRY_DISABLED to avoid build noise
ENV NEXT_TELEMETRY_DISABLED=1
# Build for production
RUN \
  if [ -f pnpm-lock.yaml ]; then pnpm build; \
  elif [ -f yarn.lock ]; then yarn build; \
  else npm run build; fi

# --- Runtime stage (standalone output) ---
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
# Next.js standalone output (Next 13+/App Router supported)
# If you use pages router, this still works with `output: 'standalone'`.
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public

# Non-root user (exists in node image)
USER node

# Next server listens on 3000 by default
EXPOSE 3003
ENV PORT=3003

# If your server entry changes, adjust this:
CMD ["node", "server.js"]
