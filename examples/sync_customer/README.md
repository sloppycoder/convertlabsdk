## Sync customer demo

This is a simple program that upload data to ConvertLab. It can be run with a single process or multiple processes managed by [Resque](https://github.com/resque/resque)
The difference is only in the startup procedure, the [syncer.rb](syncer.rb) code is used in either modes.
### Install the SDK GEM
Run the following steps to install the ConvertLabSDK GEM before running any demo program.

```
cd <convertlabsdk>
rake build
rake install
```

Install gems and setup environment variables needed by the demo program

```
cd examples/sync_customer

bundle install

# url defaults to http://api.51convert.cn if not set
export CLAB_URL=<url>
export CLAB_APPID=<appid>
export CLAB_SECRET=<secret>

# create database needed for the demo
rake db:migrate

```

### Running the demo in single process mode
```
ruby syncer.rb

```

### Running the demo in multi process mode managed by Resque

```
#
# make sure you have a Redis running locally
#

# starts the scheduler
rake resque:scheudler &

# starts the worker pool
rake resque:pool &

# startup Resque web console
rake resque:web
open http://localhost:9292/resque

```

### Docker

We can also package the applicaiton into a docker container image.
Single process model only.

```
cp ../../pkg/convertlabsdk-0.6.0.gem .
docker build -t syncer:latest .

# to run it in single process mode
docker run -d -e CLAB_APPID=$CLAB_APPID -e CLAB_SECRET=$CLAB_SECRET syncer:latest

# to run in multipe process mode using docker-compose
# it'll start a redis container for use with Resque
docker-compose up -d

# attach to the container and poke around
docker exec -it <container_id> /bin/bash

```


### TODO
* setup logging. log to file in single process model. STDOUT in docker mode
* docker compose to add PostgresSQL
