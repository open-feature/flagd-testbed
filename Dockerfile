FROM ghcr.io/open-feature/flagd:v0.4.1

COPY testing-flags.json testing-flags.json
LABEL org.opencontainers.image.source = "https://github.com/open-feature/test-harness"

ENTRYPOINT ["/flagd", "start", "-f", "file:testing-flags.json"]
