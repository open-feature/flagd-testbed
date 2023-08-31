FROM ghcr.io/open-feature/flagd:v0.6.3 as flagd

FROM busybox:1.36

COPY --from=flagd /flagd-build /flagd
COPY flags/* .
COPY scripts/* .
LABEL org.opencontainers.image.source = "https://github.com/open-feature/test-harness"

ENTRYPOINT ["sh", "wrapper.sh", "./flagd", "start", "-f", "file:testing-flags.json", "-f", "file:changing-flag.json"]
