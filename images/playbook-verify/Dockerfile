FROM alpine:3.15.4

ENV TALOS_VERSION=1.0.2

LABEL org.opencontainers.image.source https://github.com/j-lgs/provisioning

RUN \
    apk add --no-cache ansible wireguard-tools haproxy shellcheck keepalived curl && \
    curl -Lso /usr/local/bin/talosctl \
      https://github.com/siderolabs/talos/releases/download/v$TALOS_VERSION/talosctl-$(uname -s | tr "[:upper:]" "[:lower:]")-amd64 && \
    chmod +x /usr/local/bin/talosctl

ENTRYPOINT ["ansible-playbook"]
