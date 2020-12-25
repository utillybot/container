# Build frontend
FROM node:15
WORKDIR /temp/web
COPY ["web/package.json", "web/package-lock.json", "./"]
RUN npm ci
COPY web .
RUN npm run build

# Build backend
FROM node:15

# Copy package jsons for caching
WORKDIR /app/utilly
COPY ["utilly/package.json", "utilly/package-lock.json", "utilly/lerna.json", "./"]

# Copy the entire packages folder and remove anything that isn't a package.json file
COPY utilly/packages packages
RUN find utilly/packages -mindepth 2 -maxdepth 2 ! \( -name "package.json" -o -name "package-lock.json" \) -print | xargs rm -rf


# Build step 2
FROM node:15

# Copy files from previous build step aka the package jsons
WORKDIR /app/utilly
COPY --from=1 /app/utilly .

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

CMD npm run run
