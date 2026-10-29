ARG FLAGD_BASE_IMAGE=ghcr.io/open-feature/flagd:v0.18.2@sha256:a1b6de22ef4f8a4f10af2f9d0009ccef946d707d4211db342f0f2422778b764a
ARG TARGETARCH

FROM ${FLAGD_BASE_IMAGE} AS flagd

# Build stage
FROM golang:1.27@sha256:f20d83a83e18dbd2a4714b8ffd4b30b287b6243962dd75608e86abcc63ba4efc AS builder

WORKDIR /app

# Copy Go modules and dependencies
COPY launchpad/go.mod launchpad/go.sum ./
RUN go mod download

COPY launchpad/ ./

# Build the Go binary
RUN GOARCH=${TARGETARCH:-$(go env GOARCH)} go build -o launchpad main.go


FROM alpine/openssl AS certs

# Copy the server and CA certificates
COPY ssl/* ./

RUN openssl genpkey -algorithm RSA -out server-key.pem -pkeyopt rsa_keygen_bits:2048
RUN openssl req -new -key server-key.pem -out server.csr -subj "/CN=localhost" \
      -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
   && openssl x509 -req -in server.csr -CA custom-root-cert.crt -CAkey custom-ca.key -CAcreateserial -out server-cert.pem -days 365 -sha256 \
      -copy_extensions copy

FROM busybox:1.38@sha256:dc2d74b28e4cf8984fa52af1f39bc7c3d9c73760b41a74d629f5d11b1ab28616 AS testbed

COPY --from=flagd /flagd-build /flagd
COPY --from=builder /app/launchpad /launchpad
COPY flags/* ./rawflags/
COPY launchpad/configs /configs

# Copy the custom root CA certificate into the image

COPY --from=certs server-cert.pem /ssl/
COPY --from=certs server-key.pem /ssl/
COPY --from=certs custom-root-cert.crt /ssl/

RUN mkdir "flags"

LABEL org.opencontainers.image.source="https://github.com/open-feature/flagd-testbed"

ENTRYPOINT ["./launchpad"]

