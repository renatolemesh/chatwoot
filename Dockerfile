# Dockerfile
# Build Chatwoot from THIS repository source
FROM ruby:3.4.4-slim AS builder

ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/bundle

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    ca-certificates \
    pkg-config \
    libpq-dev \
    python3 \
    libvips \
  && rm -rf /var/lib/apt/lists/*

# Node.js for Builder
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get update && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# pnpm via corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Ruby deps
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

# JS deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# App source
COPY . .

# Build-time secret key base requirement for assets precompile
ARG SECRET_KEY_BASE=dummy

# Precompile assets with increased Node.js heap to avoid OOM during Vite build
RUN export NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" && \
    SECRET_KEY_BASE=${SECRET_KEY_BASE} \
    RAILS_LOG_TO_STDOUT=enabled \
    bundle exec rails assets:precompile && \
    rm -rf node_modules tmp/cache


FROM ruby:3.4.4-slim AS runtime

ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/bundle \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# Runtime dependencies including postgresql-client, git, and Node.js
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libvips \
    postgresql-client \
    git \
    curl \
    ca-certificates \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /bundle /bundle
COPY --from=builder /app /app

EXPOSE 3002

# Default: migrate then start web.
CMD ["bash", "-lc", "bundle exec rails db:migrate && bundle exec rails s -b 0.0.0.0 -p 3002"]
