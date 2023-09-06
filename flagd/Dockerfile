# we NEED flagd v0.6.4 as a minimum
FROM ghcr.io/open-feature/flagd:v0.6.4 as flagd

FROM busybox:1.36

COPY --from=flagd /flagd-build /flagd
COPY flags/* .
COPY scripts/* .
LABEL org.opencontainers.image.source = "https://github.com/open-feature/flagd-testbed"

ENTRYPOINT ["sh", "wrapper.sh", "./flagd", "start", \
    "-f", "file:testing-flags.json", \
    "-f", "file:changing-flag.json", \
    "-f", "file:custom-ops.json", \
    "-f", "file:evaluator-refs.json", \
    "-f", "file:zero-flags.json"]
