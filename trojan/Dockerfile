FROM p4gefau1t/trojan-go

RUN apk update && apk add gettext

COPY ./templates /etc/trojan-go/templates

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]