FROM ruby:2.2
MAINTAINER Li Lin <guru.lin@gmail..com>

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /app
COPY . /app

WORKDIR /app
RUN gem install convertlabsdk-0.6.0.gem
RUN bundle install

VOLUME /data

ENTRYPOINT ["ruby", "bin/sync_customer.rb"]
CMD ["docker"]
