FROM dart:beta

RUN echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> /root/.bashrc
RUN dart --disable-analytics
RUN dart pub global activate webdev