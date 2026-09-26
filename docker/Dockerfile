FROM pihole/pihole:2026.09.0
# Set by CI to the current Alpine package version so a changed Unbound misses the layer cache
ARG UNBOUND_VERSION
RUN apk update && apk add "unbound${UNBOUND_VERSION:+=$UNBOUND_VERSION}"

COPY lighttpd-external.conf /etc/lighttpd/external.conf 
COPY unbound-pihole.conf /etc/unbound/unbound.conf.d/pi-hole.conf
COPY 99-edns.conf /etc/dnsmasq.d/99-edns.conf
RUN mkdir -p /etc/services.d/unbound

COPY custom-entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

ENTRYPOINT ["/custom-entrypoint.sh"]
