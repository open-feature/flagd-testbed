ARG FLAGD_BASE_IMAGE=ghcr.io/open-feature/flagd:v0.16.3@sha256:a11ae82ec6e40e89edae4327392a1e4ffc03e211f1b724879bb35b2e4f271bb3
ARG TARGETARCH

FROM ${FLAGD_BASE_IMAGE} AS flagd

# Build stage
FROM golang:1.25@sha256:699337d620559a59b4a2bb298ad59611e535d2ee755a34cf2d2a98f37578dc80 AS builder

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
   && openssl x509 -req -in server.csr -CA custom-root-cert.crt -CAkey custom-ca.key -CAcreateserial -out server-cert.pem -days 365 -sha256

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

