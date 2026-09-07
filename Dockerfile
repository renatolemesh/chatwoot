# =========================
# BUILDER
# =========================
FROM ruby:3.4.4-slim AS builder

ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/bundle

# System deps
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

# Node 24 (package.json declara engines: node 24.x)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt-get update && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# pnpm (via corepack)
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Ruby deps
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

# JS deps
COPY package.json pnpm-lock.yaml ./

# 🔥 INSTALAÇÃO CORRETA (resolve Vite + Chart.js)
RUN rm -rf node_modules && \
    pnpm install --no-frozen-lockfile --shamefully-hoist

# App
COPY . .

# Build assets
ARG SECRET_KEY_BASE=dummy

RUN export NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" && \
    SECRET_KEY_BASE=${SECRET_KEY_BASE} \
    RAILS_LOG_TO_STDOUT=enabled \
    bundle exec rails assets:precompile && \
    rm -rf node_modules tmp/cache


# =========================
# RUNTIME
# =========================
FROM ruby:3.4.4-slim

ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/bundle \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# Runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libvips \
    postgresql-client \
    git \
    curl \
    ca-certificates \
  && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# pnpm também no runtime (pra debug futuro)
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY --from=builder /bundle /bundle
COPY --from=builder /app /app

EXPOSE 3002

CMD ["bash", "-lc", "bundle exec rails db:migrate && bundle exec rails s -b 0.0.0.0 -p 3002"]