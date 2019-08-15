#/bin/bash

# Check if nginx is running. Exit code 0 is running
nginx_running () {
  service nginx status | grep not
  if [ $? -eq 1 ]; then return 0 ; else return 1 ; fi
}

# Check if postgres is running. Exit code 0 is running
postgres_running () {
  service postgresql status | grep online
  return
}

# Build conceptnet5
build () {
  echo "Starting building of ConceptNet graph from raw data"
  service postgresql start
  sudo -H -u conceptnet sh -c 'cd /home/conceptnet/conceptnet5; \
    . ../env/bin/activate ; ./build.sh'
  service postgresql stop
  exit 0
}

start () {
  echo "Starting services"
  service postgresql start

  # Start the apps in emperor mode
  # https://uwsgi-docs.readthedocs.io/en/latest/Emperor.html
  echo " * Starting Conceptnet web app"
  sudo -H -u conceptnet sh -c '/home/conceptnet/env/bin/uwsgi \
    --daemonize /home/conceptnet/uwsgi-emperor.log \
    --ini /home/conceptnet/uwsgi/emperor.ini \
    --safe-pidfile /tmp/uwsgi-conceptnet.pid'
  #TODO add healthcheck for the service for restarting it and to start
  # the web-server
  echo "   ...done."

  # Start web-server last
  service nginx start

  # Restart the services if they fail
  while sleep 15; do
    postgres_running
    if [ $? -ne 0 ]; then service postgresql restart; fi
    nginx_running
    if [ $? -ne 0 ]; then service nginx restart; fi
  done
}

stop () {
  echo "Stopping services"
  service nginx stop
  service postgresql stop
  # tried to do it the proper way, but uwsgi is not writing the pid file and I don't have time to figure out why...
  # kill -INT `cat /tmp/uwsgi-conceptnet.pid`
  # so instead just kill it:
  sudo pkill -f uwsgi -9
  if [ -z "$CHILD" ]; then
    kill -TERM "$CHILD"
  fi
  exit 0
}

trap_handler () {
  printf "\nThe trap handler has been fired with signal = $1 \n"
  stop
}

# For Ctrl + c
trap 'trap_handler SIGINT' SIGINT
# For docker stop
trap 'trap_handler SIGTERM' SIGTERM

CHILD=""
arg="$@"
if [ "$arg" == "start"]; then
  start
elif [ "$arg" == "build"]; then
  build
elif [ "$arg" == "stop"]; then
  stop
else
  eval $@ &
  CHILD=$!
  wait "$CHILD"
fi
