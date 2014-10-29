FROM ubuntu:14.04
MAINTAINER Amit Aharoni <amit.sites@gmail.com>

RUN apt-get -y update
RUN apt-get -y install build-essential ruby

RUN groupadd app && useradd -m -G app -d /home/sandbox sandbox

RUN gem install bundler
ADD Gemfile /home/sandbox/Gemfile
ADD bundle_config /home/sandbox/.bundle/config
RUN chown sandbox /home/sandbox/Gemfile && \
    chown sandbox /home/sandbox/.bundle && \
    chown sandbox /home/sandbox/.bundle/config && \
    sudo -u sandbox -i bundle install

ADD entrypoint.sh entrypoint.sh
ADD run.rb /home/sandbox/run.rb
RUN chown sandbox /home/sandbox/run.rb

ENTRYPOINT ["/bin/bash", "entrypoint.sh"]