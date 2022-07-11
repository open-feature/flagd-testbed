FROM ghcr.io/open-feature/flagd:latest

COPY testing-flags.json testing-flags.json

ENTRYPOINT ["/flagd", "start", "-f", "testing-flags.json"]
