FROM alpine:latest as downloader

RUN wget https://github.com/Secretmapper/combustion/archive/release.zip && \
    unzip release.zip && \
    wget https://raw.githubusercontent.com/SebDanielsson/dark-combustion/master/main.77f9cffc.css

FROM alpine:latest

# maintainer
LABEL maintainer "Sebastian Danielsson <sebastian.danielsson@protonmail.com>"

# install wireguard-tools transmission-daemon
RUN apk --no-cache --virtual add wireguard-tools transmission-daemon jq 

# copy placeholder config files and startup script from host
COPY root/ .

# create volumes to load config files from host and save downloaded files to host
VOLUME ["/etc/wireguard"] \
        ["/etc/transmission-daemon"] \
        ["/transmission/complete"] \
        ["/transmission/incomplete"] \
        ["/transmission/watch"]

COPY --from=downloader /combustion-release \
    /main.77f9cffc.css \
    tmp/combustion-release/

RUN rm -rf /usr/share/transmission/web && \
    mv /tmp/combustion-release/ /usr/share/transmission/web && \
    rm -rf /tmp/combustion-release && \
    chmod +x /entrypoint.sh

# open ports, 51820 for WireGuard, 9091 for transmission-rpc
EXPOSE 51820/udp 9091

ENTRYPOINT [ "/entrypoint.sh" ]
