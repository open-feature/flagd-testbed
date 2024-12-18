# we NEED flagd v0.6.4 as a minimum
FROM ghcr.io/open-feature/flagd:v0.11.5 AS flagd

FROM busybox:1.37 AS testbed

COPY --from=flagd /flagd-build /flagd
COPY flags/* .
COPY scripts/* .
LABEL org.opencontainers.image.source="https://github.com/open-feature/flagd-testbed"

ENTRYPOINT ["sh", "change-flag-wrapper.sh", "./flagd", "start", \
    "-f", "file:testing-flags.json", \
    "-f", "file:changing-flag.json", \
    "-f", "file:custom-ops.json", \
    "-f", "file:evaluator-refs.json", \
    "-f", "file:edge-case-flags.json", \
    "-f", "file:zero-flags.json"]

FROM testbed AS unstable

ENTRYPOINT ["sh", "restart-wrapper.sh", "./flagd", "start", \
    "-f", "file:testing-flags.json"]

FROM alpine/openssl AS certs

# Copy the server and CA certificates
COPY ssl/* ./

RUN openssl genpkey -algorithm RSA -out server-key.pem -pkeyopt rsa_keygen_bits:2048
RUN openssl req -new -key server-key.pem -out server.csr -subj "/CN=localhost" \
   && openssl x509 -req -in server.csr -CA custom-root-cert.crt -CAkey custom-ca.key -CAcreateserial -out server-cert.pem -days 365 -sha256

FROM testbed AS ssl

# Copy the custom root CA certificate into the image

COPY --from=certs server-cert.pem /etc/ssl/certs/
COPY --from=certs server-key.pem /etc/ssl/private/
COPY --from=certs custom-root-cert.crt /etc/ssl/certs/


ENTRYPOINT ["./flagd", "start",\
    "-f", "file:testing-flags.json", \
    "-c", "/etc/ssl/certs/server-cert.pem", \
    "-k", "/etc/ssl/private/server-key.pem"]
