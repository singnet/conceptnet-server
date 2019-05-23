# Conceptnet5 Containerized Server

This project contains a Dockerfile that allows the creation of conceptnet5
server ready images.

It uses configuration from https://github.com/commonsense/conceptnet-puppet,
and procedure described at https://github.com/commonsense/conceptnet5/wiki/Build-process

##  Configuring and running the server

The helper function `run.sh` is used for this

```
Usage: bash run.sh command [build-label]

Commands:
  build  Build the conceptnet database.
  setup  Build the docker image.
  shell  Start a container and drop into the shell without starting
         the conceptnet server.
  start  Start the container as a background process with the
         conceptnet server running and port 8084 exposed locally.
```

## Performing queries using curl

In order to perform the query "c/en/tree" to your server do the following.

```
curl http://0.0.0.0:8084/c/en/tree
```

## Scheme client API

A client api for Scheme is provided in a scheme module in api/scheme/conceptnet.scm
