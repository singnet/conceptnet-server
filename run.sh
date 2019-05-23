#!/bin/bash

#TODO; Configure to keep nginx, postgres, and conceptnet logs between runs.

tag="${2:+:$2}"
label="${2:+-$2}"
image="conceptnet$tag"
container="conceptnet-server$label"

docker-run () {
  # The whole /home/conceptnet folder is targeted as a volume so as to
  # backup the concpetnet version between image builds. This way the
  # images could be updated for security and containers restarted with
  # existing setup.
  docker run --name $container --stop-timeout 30 \
    --mount source="conceptnet-data$label",target=/home/conceptnet/ \
    --mount source="conceptnet-db$label",target=/var/lib/postgresql/10/main $@
}

help () {
  echo "Usage: bash run.sh command [build-label]"
  echo ""
  echo "Commands:"
  echo "  build  Build the conceptnet database."
  echo "  setup  Build the docker image."
  echo "  shell  Start a container and drop into the shell without starting"
  echo "         the conceptnet server."
  echo "  start  Start the container as a background process with the"
  echo "         conceptnet server running and port 7082 exposed locally."
}

case $1 in
  build) docker-run --rm -it $image build ;;
  setup) docker build -t $image . ;;
  start) docker-run -p 7082:80 --rm -d $image ;;
  shell) docker-run --rm -it $image exec bash ;;
  *) help ;;
esac

