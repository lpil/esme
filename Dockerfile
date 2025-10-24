ARG NODE_VERSION=25.0.0
ARG GLEAM_VERSION=1.13.0

# Gleam stage
FROM ghcr.io/gleam-lang/gleam:v${GLEAM_VERSION}-scratch AS gleam

# Build stage
FROM node:${NODE_VERSION}-alpine AS build
COPY --from=gleam /bin/gleam /bin/gleam
COPY . /app/
RUN \
  cd /app \
  && gleam build \
  && esbuild --bundle build/dev/javascript/esme/gleam.main.mjs --platform=node --target=node${NODE_VERSION} > /app/esme.js

# Final stage
FROM node:${NODE_VERSION}-alpine AS build
ARG GIT_SHA
ARG BUILD_TIME
ENV GIT_SHA=${GIT_SHA}
ENV BUILD_TIME=${BUILD_TIME}
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp
COPY --from=build /app/esme.js /app/esme.js
COPY healthcheck.sh /app/healthcheck.sh
VOLUME /app/data
LABEL org.opencontainers.image.source=https://github.com/lpil/esme
LABEL org.opencontainers.image.description="GPS tracker for Esme boat"
LABEL org.opencontainers.image.licenses=Apache-2.0
WORKDIR /app
CMD ["node", "/app/esme.js", "--", "--directory", "/app/data"]
