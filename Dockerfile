# syntax=docker/dockerfile:1
FROM ruby:3.2-alpine

# Install build deps for discordrb (libsodium, openssl) and runtime deps.
RUN apk add --no-cache build-base openssl-dev libsodium-dev git

WORKDIR /app

# Install gems first (cache layer) then copy app.
COPY Gemfile Gemfile.lock ./
RUN bundle config set without 'development test' \
 && bundle install --jobs 4 --retry 3

COPY . .

CMD ["bundle", "exec", "ruby", "bot.rb"]
