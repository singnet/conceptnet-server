# Image to be used
FROM ubuntu:16.04

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Update and install deps
RUN apt-get update && apt-get install -y sudo git

# Install dependencies
RUN git clone https://github.com/singnet/conceptnet-puppet; \
        cd conceptnet-puppet; \
        echo yes | sh puppet-setup.sh

# Configure the conceptnet server
# NOTES
# - Stop the postgres service so as to get a faster start of the service
#   during docker run.
# - The errors related with systemctl is because systemd can't run in the
#   default docker configuration; it has no effect for building and running
#   the conceptnet server
RUN cd conceptnet-puppet; \
        sh puppet-apply.sh

COPY conceptnet.sh .

RUN apt-get update && apt-get install -y postgresql-server-dev-10
RUN cd /home/conceptnet/conceptnet5/web && /home/conceptnet/env/bin/pip3 install -e .

USER postgres
RUN wget https://tz-services-1.snet.sh/conceptnet-dumps/conceptnet5-pg-dump-20190502 -O /tmp/conceptnet5-pg-dump-20190502 && service postgresql start && pg_restore -h /var/run/postgresql/ -j20 --clean -U postgres --dbname=conceptnet5 /tmp/conceptnet5-pg-dump-20190502 || true && service postgresql stop && rm /tmp/conceptnet5-pg-dump-20190502

# May be we can noot use then postgres user. But this works.
USER root
ENTRYPOINT ["bash", "conceptnet.sh"]
CMD ["start"]
# TODO
# - Add healthcheck
# - Do gracefule shutdown of uwsgi emperor

