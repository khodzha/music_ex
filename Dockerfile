FROM elixir:1.5.1 as builder

RUN apt-get -qq update
RUN apt-get -qq install git build-essential

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info


WORKDIR /app
ENV MIX_ENV prod
ADD . .
RUN mix deps.get
RUN mix release --env=$MIX_ENV


FROM debian:jessie-slim
RUN echo deb http://ftp.de.debian.org/debian jessie main >> /etc/apt/sources.list
RUN apt-get -qq update
RUN apt-get -qq install libssl1.0.0 libssl-dev
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update -qq && apt-get install -y locales -qq && locale-gen en_US.UTF-8 en_us && dpkg-reconfigure locales && dpkg-reconfigure locales && locale-gen C.UTF-8 && /usr/sbin/update-locale LANG=C.UTF-8
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8
ENV LC_ALL C.UTF-8
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/music_ex .
# ADD dca-rs ./bin/dca-rs
# ADD youtube-dl ./bin/youtube-dl
# ENV PATH "./bin/:${PATH}"

CMD ["./bin/music_ex", "foreground"]
