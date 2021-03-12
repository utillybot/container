# ------------------------------
# Build frontend

FROM node:15
WORKDIR /temp/web
COPY ["web/package.json", "web/package-lock.json", "./"]
RUN npm ci
COPY web .
RUN npm run build

# ------------------------------
# Build server

FROM golang:1.16
WORKDIR /temp/server
COPY ["server", "./"]
RUN go build -o ./dist/main main.go

# ------------------------------
# Build bot

FROM node:15

# Copy package jsons for caching
WORKDIR /app/utilly
COPY ["utilly/package.json", "utilly/package-lock.json", "utilly/lerna.json", "./"]

# Copy the entire packages folder and remove anything that isn't a package.json file
COPY utilly/packages packages
RUN find packages -mindepth 2 -maxdepth 2 ! \( -name "package.json" -o -name "package-lock.json" \) -print | xargs rm -rf

# Build step 2
FROM node:15

# Move over package.json files. This build step enables caching
WORKDIR /app/utilly
COPY --from=2 /app/utilly .

# Install dependencies
RUN npm ci
RUN npx lerna bootstrap --ci

# Copy over files
COPY /utilly .

# Readd symlinks
RUN npx lerna bootstrap --ci

# Set production to run a production build
ENV NODE_ENV=production
RUN npm run build
RUN npm prune

ENV BASE_WEB_URL=/app/web
COPY --from=0 /temp/web/dist /app/web
COPY --from=1 /temp/server/dist /app/server

# Supervisor config
COPY --from=ochinchina/supervisord:latest /usr/local/bin/supervisord /usr/local/bin/supervisord
COPY supervisor.conf /etc/supervisord.conf
CMD ["supervisord"]

