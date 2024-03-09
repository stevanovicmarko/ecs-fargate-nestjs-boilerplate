# Base image
FROM node:20-alpine as BUILD
WORKDIR /app

# Copy build files
COPY package*.json ./
COPY nest-cli.json ./
COPY .eslintrc.js ./
COPY tsconfig*.json ./
COPY ./src ./src

# Install build dependencies and build the app
RUN npm ci && npm run build

FROM node:20-alpine as PRODUCTION

# Install curl
RUN apk --no-cache add curl

WORKDIR /app
# Copy package.json and install production dependencies
COPY package*.json ./
RUN npm install --production
COPY --from=BUILD /app/dist/ dist/

EXPOSE 3000

HEALTHCHECK CMD curl --fail http://localhost:3000/api/healthcheck || exit 1

# Start the server using the production build
CMD ["npm", "run", "start:prod"]
