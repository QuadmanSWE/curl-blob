FROM alpine@sha256:c5b1261d6d3e43071626931fc004f70149baeba2c8ec672bd4f27761f8e1ad6b

RUN apk add --no-cache curl openssl

COPY upload.sh /upload.sh

ENTRYPOINT ["/bin/sh", "/upload.sh"]