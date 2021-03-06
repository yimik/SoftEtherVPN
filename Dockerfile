FROM alpine:3.9 as prep

ENV BUILD_VERSION=4.29-9680-rtm \
    SHA256_SUM=c19cd49835c613cb5551ce66c91f90da3d3496ab3e15e8c61e22b464dc55d9b0

RUN wget https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/archive/v${BUILD_VERSION}.tar.gz \
    && echo "${SHA256_SUM}  v${BUILD_VERSION}.tar.gz" | sha256sum -c \
    && mkdir -p /usr/local/src \
    && tar -x -C /usr/local/src/ -f v${BUILD_VERSION}.tar.gz \
    && rm v${BUILD_VERSION}.tar.gz

FROM alpine:3.9 as build

COPY --from=prep /usr/local/src /usr/local/src

ENV LANG=en_US.UTF-8

RUN cd /usr/local/src/SoftEtherVPN_Stable-* \
    && sed -i '/bool SiIsEnterprise/,/^}/c bool SiIsEnterpriseFunctionsRestrictedOnOpenSource(CEDAR *c){ return false; }' src/Cedar/Server.c

RUN apk add -U build-base ncurses-dev openssl-dev readline-dev zip zlib-dev \
    && cd /usr/local/src/SoftEtherVPN_Stable-* \
    && ./configure \
    && make \
    && make install \
    && touch /usr/vpnserver/vpn_server.config \
    && zip -r9 /artifacts.zip /usr/vpn* /usr/bin/vpn*

FROM alpine:3.9

COPY --from=build /artifacts.zip /

COPY copyables /

ENV LANG=en_US.UTF-8

RUN apk add -U --no-cache bash iptables openssl-dev \
    && chmod +x /entrypoint.sh /gencert.sh \
    && unzip -o /artifacts.zip -d / \
    && rm /artifacts.zip \
    && rm -rf /opt \
    && ln -s /usr/vpnserver /opt \
    && find /usr/bin/vpn* -type f ! -name vpnserver \
       -exec sh -c 'ln -s {} /opt/$(basename {})' \;

WORKDIR /usr/vpnserver/

VOLUME ["/usr/vpnserver/server_log/"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 500/udp 4500/udp 1701/tcp 1194/udp 5555/tcp 443/tcp

CMD ["/usr/bin/vpnserver", "execsvc"]