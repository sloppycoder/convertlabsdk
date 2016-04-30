FROM ruby:2.2
MAINTAINER Li Lin <guru.lin@gmail..com>

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /app
COPY . /app

WORKDIR /app
RUN gem install convertlabsdk-0.6.0.gem
RUN bundle install

RUN mkdir -p /data
VOLUME /data
VOLUME /app/config

# resque console is accessible from this port
EXPOSE 9292

ENTRYPOINT ["/bin/bash", "/app/docker-entrypoint.sh"]
CMD ["single"]
