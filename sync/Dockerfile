FROM busybox:1.36

COPY sync/bin/* .
COPY flags/* .
COPY scripts/* .
LABEL org.opencontainers.image.source = "https://github.com/open-feature/test-harness"

ENTRYPOINT ["sh", "wrapper.sh", "./sync", "start", "-f", "testing-flags.json", "-f", "changing-flag.json"]
