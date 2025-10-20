FROM ruby:3.4

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      build-essential git curl ca-certificates \
      libsqlite3-dev pkg-config && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && npm i -g yarn && \
    rm -rf /var/lib/apt/lists/*

RUN gem install bundler

WORKDIR /workspaces/textae_canvas

COPY Gemfile Gemfile.lock ./
RUN bundle install

EXPOSE 3000
