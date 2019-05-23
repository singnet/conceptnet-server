# Image to be used
FROM ubuntu:16.04

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Update and install deps
RUN apt-get update && apt-get install -y sudo git

# Install dependencies
RUN git clone https://github.com/commonsense/conceptnet-puppet; \
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
	sh puppet-apply.sh; \
	service postgresql stop

COPY conceptnet.sh .

ENTRYPOINT ["bash", "conceptnet.sh"]
CMD ["start"]
# TODO
# - Add healthcheck
# - Do gracefule shutdown of uwsgi emperor

