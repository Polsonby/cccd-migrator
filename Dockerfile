FROM ruby:2.6.5-alpine3.10
MAINTAINER Ministry of Justice, Claim for crown court defence <crowncourtdefence@digital.justice.gov.uk>

# fail early and print all commands
RUN set -ex

# add non-root user and group with alpine first available uid, 1000
RUN addgroup -g 1000 -S appgroup \
&& adduser -u 1000 -S appuser -G appgroup

RUN apk --no-cache update \
    && apk --no-cache add \
      --virtual build-dependencies build-base \
    && apk --no-cache add \
    bash \
    python py-pip py-setuptools \
    ca-certificates\
    curl less groff \
    postgresql \
    && pip --no-cache-dir install awscli --upgrade \
    && rm -rf /var/cache/apk/*

RUN mkdir -p /usr/src/app && mkdir -p /usr/src/app/tmp
WORKDIR /usr/src/app

COPY Gemfile* ./

# note: installs bundler version used in Gemfile.lock
#
RUN gem install bundler -v $(cat Gemfile.lock | tail -1 | tr -d " ") && bundle install

COPY . .

# tidy up installation
RUN apk update && apk del build-dependencies

# expect/add ping environment variables
ARG VERSION_NUMBER
ARG COMMIT_ID
ARG BUILD_DATE
ARG BUILD_TAG
ENV VERSION_NUMBER=${VERSION_NUMBER}
ENV COMMIT_ID=${COMMIT_ID}
ENV BUILD_DATE=${BUILD_DATE}
ENV BUILD_TAG=${BUILD_TAG}

USER 1000
CMD ["bash", "-c", "sleep 86400"]