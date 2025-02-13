FROM ruby:latest

WORKDIR /src

COPY . .

COPY Gemfile Gemfile.lock ./

RUN gem install bundler

RUN bundle install --full-index

RUN rake install

RUN echo 'alias build="gem build confset.gemspec"' >> ~/.bashrc

RUN echo 'alias release="rake release"' >> ~/.bashrc

RUN echo 'alias release_github="gem push --key github --host https://rubygems.pkg.github.com/dcotecnologia "' >> ~/.bashrc

CMD ["irb"]
