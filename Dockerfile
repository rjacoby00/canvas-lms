# GENERATED FILE, DO NOT MODIFY!
# To update this file please edit the relevant template and run the generation
# task `build/dockerfile_writer.rb --env development --compose-file docker-compose.yml,docker-compose.override.yml --in build/Dockerfile.template --out Dockerfile`

ARG RUBY=2.6

FROM instructure/passenger-nginx-alpine:${RUBY} AS dependencies
LABEL maintainer="Instructure"

ARG POSTGRES_CLIENT=12.2
ARG ALPINE_MIRROR=http://dl-cdn.alpinelinux.org/alpine
ARG NODE=10.19.0-r0

ENV APP_HOME /usr/src/app/
ENV RAILS_ENV production
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

WORKDIR $APP_HOME
COPY --chown=docker:docker config/canvas_rails_switcher.rb ${APP_HOME}/config/canvas_rails_switcher.rb
COPY --chown=docker:docker Gemfile   ${APP_HOME}
COPY --chown=docker:docker Gemfile.d ${APP_HOME}Gemfile.d

COPY --chown=docker:docker gems      ${APP_HOME}gems

ENV GEM_HOME /home/docker/.gem/$RUBY_VERSION
ENV PATH $GEM_HOME/bin:$PATH
ENV BUNDLE_APP_CONFIG /home/docker/.bundle

USER root
RUN set -eux; \
  \
  # create APP_HOME \
  chown docker:docker $APP_HOME \
  \
  # select a specific alpine repo mirror \
  && sed -i -E "s|http://dl-cdn.alpinelinux.org/alpine|${ALPINE_MIRROR}|g" /etc/apk/repositories \
  # these packages will be kept in the final image \
  && apk add --no-cache \
    # NOTE: why bash? some scripts have not been rewritten to be POSIX \
    # compliant, like rspec-with-retries.sh \
    # it would be ideal to get these scripts updated, but in the meantime  \
    # bash isn't the largest library so for size concerns it's not a dealbreaker \
    bash \
    coreutils \
    file \
    g++ \
    git \
    icu-dev \
    imagemagick \
    libffi-dev \
    libxml2-dev \
    libxslt-dev \
    make \
    postgresql-client~=$POSTGRES_CLIENT \
    postgresql-dev~=$POSTGRES_CLIENT \
    # TODO: need to upgrade to python 3 \
    py2-pip \
    python2 \
    ruby-dev \
    sqlite \
    sqlite-dev \
    tzdata \
    xmlsec \
    xmlsec-dev \
  && apk add --no-cache --virtual .pbzip2deps \
    bzip2-dev \
  \
  && apk add --no-cache --repository http://mirrors.gigenet.com/alpinelinux/v3.10/main \
    # qti_migration_tool dependency \
    py2-lxml \
  \
  # TODO: extract to its own build in a multi-image workflow \
  # pbzip2 installation \
  && cd /tmp/ \
  && wget -q https://launchpad.net/pbzip2/1.1/1.1.13/+download/pbzip2-1.1.13.tar.gz \
  && tar -xzf pbzip2-1.1.13.tar.gz \
  && cd pbzip2-1.1.13/ \
  && make install \
  && apk del --no-network .pbzip2deps \
  && cd $APP_HOME \
  && rm -r /tmp/pbzip2-1.1.13/ \
  \
  # python symlinks \
  && ln -s /usr/bin/python2 /usr/local/bin/python

USER docker
RUN set -eux; \
  \
  # set up bundle config options \
  bundle config --global build.nokogiri --use-system-libraries \
  && bundle config --global build.ffi --enable-system-libffi \
  && mkdir -p \
    /home/docker/.gem/$RUBY_VERSION \
    /home/docker/.bundle \
  # TODO: --without development \
  && bundle install --jobs $(nproc) \
  && rm -rf $GEM_HOME/cache

USER root
RUN set -eux; \
  \
  # these packages are temporary for generating this image \
  apk add --no-cache --virtual .builddeps --repository $ALPINE_MIRROR/v3.10/main \
    g++ \
    make \
    libsass \
  # these packages stick around in the final image \
  && apk add --no-cache --repository $ALPINE_MIRROR/v3.10/main \
    npm \
    nodejs=${NODE} \
    yarn \
  && apk add --no-cache curl \
  && cd /tmp \
  && curl -Ls https://github.com/instructure/phantomized/releases/download/2.1.1a/dockerized-phantomjs.tar.gz | tar xzv -C / \
  && curl -k -Ls https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 | tar -jxf - \
  && cp phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin/phantomjs \
  && apk del --no-network curl \
  && rm -rf /tmp/*

USER docker
COPY --chown=docker:docker package.json ${APP_HOME}
COPY --chown=docker:docker yarn.lock    ${APP_HOME}

COPY --chown=docker:docker client_apps  ${APP_HOME}client_apps
COPY --chown=docker:docker packages     ${APP_HOME}packages

RUN set -eux; \
  mkdir -p .yardoc \
             app/stylesheets/brandable_css_brands \
             app/views/info \
             client_apps/canvas_quizzes/dist \
             client_apps/canvas_quizzes/node_modules \
             client_apps/canvas_quizzes/tmp \
             config/locales/generated \
             gems/canvas_i18nliner/node_modules \
             log \
             node_modules \
             packages/canvas-media/es \
             packages/canvas-media/lib \
             packages/canvas-media/node_modules \
             packages/canvas-planner/lib \
             packages/canvas-planner/node_modules \
             packages/canvas-rce/canvas \
             packages/canvas-rce/lib \
             packages/canvas-rce/node_modules \
             packages/jest-moxios-utils/node_modules \
             packages/js-utils/es \
             packages/js-utils/lib \
             packages/js-utils/node_modules \
             packages/k5uploader/es \
             packages/k5uploader/lib \
             packages/k5uploader/node_modules \
             packages/old-copy-of-react-14-that-is-just-here-so-if-analytics-is-checked-out-it-doesnt-change-yarn.lock/node_modules \
             pacts \
             public/dist \
             public/doc/api \
             public/javascripts/client_apps \
             public/javascripts/compiled \
             public/javascripts/translations \
             reports \
             tmp \
             /home/docker/.bundler/ \
             /home/docker/.cache/yarn \
             /home/docker/.gem/ \
  && (DISABLE_POSTINSTALL=1 yarn install --pure-lockfile || DISABLE_POSTINSTALL=1 yarn install --pure-lockfile --network-concurrency 1) \
  && yarn cache clean

COPY --chown=docker:docker babel.config.js ${APP_HOME}
COPY --chown=docker:docker script          ${APP_HOME}script

RUN yarn postinstall

FROM dependencies AS webpack-final
ARG JS_BUILD_NO_UGLIFY=0

COPY --chown=docker:docker . ${APP_HOME}
RUN COMPILE_ASSETS_NPM_INSTALL=0 JS_BUILD_NO_UGLIFY="$JS_BUILD_NO_UGLIFY" bundle exec rails canvas:compile_assets
