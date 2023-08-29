FROM ghcr.io/open-feature/flagd:v0.6.3 as flagd

FROM busybox:1.36

COPY --from=flagd /flagd-build /flagd
COPY flags/* .
COPY wrapper.sh .
LABEL org.opencontainers.image.source = "https://github.com/open-feature/test-harness"

ENTRYPOINT ["sh", "wrapper.sh"]
