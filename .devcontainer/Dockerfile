FROM --platform=linux/amd64 debian:12-slim

RUN apt-get update
RUN apt-get install -y wget unzip git
RUN wget https://storage.googleapis.com/dart-archive/channels/dev/release/3.5.0-164.0.dev/sdk/dartsdk-linux-x64-release.zip
RUN unzip dartsdk-linux-x64-release.zip -d /usr/lib/
ENV DART_SDK=/usr/lib/dart-sdk
ENV PATH=$PATH:/usr/lib/dart-sdk/bin:/root/.pub-cache/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN dart --disable-analytics
RUN dart pub global activate webdev