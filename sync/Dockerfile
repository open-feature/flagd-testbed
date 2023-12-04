FROM golang:1.21-alpine AS builder

WORKDIR /src

COPY sync .
RUN go mod download
RUN go build -o sync

FROM busybox:1.36

COPY --from=builder /src/sync .
COPY flags/* .
COPY scripts/* .
LABEL org.opencontainers.image.source = "https://github.com/open-feature/flagd-testbed"

ENTRYPOINT ["sh", "change-flag-wrapper.sh", "./sync", "start", \
    "-f", "testing-flags.json", \
    "-f", "changing-flag.json", \
    "-f", "custom-ops.json", \
    "-f", "evaluator-refs.json", \
    "-f", "edge-case-flags.json", \
    "-f", "zero-flags.json"]
