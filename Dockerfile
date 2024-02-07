FROM ubuntu:23.10 as builder

ENV MODE="1"
ENV NGINX_VERSION="1"
ENV HEADER_MORE="y"
ENV SSL_FINGERPRINT="y"
ENV OPENSSL="2"
ENV BROTLI="y"
ENV TEST_COOKIE="y"
ENV SUBSTITUTIONS_FILTER="y"
ENV CACHE_PURGE="y"
ENV HTTP3="y"
ENV COOKIE_FLAG="y"
ENV NAXSI="y"
ENV DOCKER_GEN="y"

WORKDIR /tmp
COPY nginx-installer.sh /tmp/nginx-installer.sh
RUN chmod +x nginx-installer.sh && \
    ./nginx-installer.sh

CMD ["nginx", "-g", "daemon off;"]