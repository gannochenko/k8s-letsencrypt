FROM fedora:latest

RUN dnf install jq certbot -y && dnf clean all
RUN mkdir -p /etc/letsencrypt

CMD ["/entrypoint.sh"]

COPY ./templates /templates/
COPY entrypoint.sh /
