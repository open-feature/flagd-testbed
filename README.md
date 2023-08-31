# OpenFeature Test Harness

This repository contains a docker image to support the [gherkin suites](https://github.com/open-feature/spec/blob/main/specification/appendix-b-gherkin-suites.md) in the OpenFeature specification.

## flagd-testbed container

The _flagd-testbed_ container is a docker image built on flagd, which essentially just adds a simple set of flags for the purposes of testing OpenFeature SDKs.
`testing-flags.json` contains a set of flags consistent with the [evaluation feature](https://github.com/open-feature/spec/blob/main/specification/assets/gherkin/evaluation.feature).
`change-flag.sh` runs in the test container generates a file `changing-flag.json`, which contains a flag that changes once every seconds, allowing to easily test change events.

See the [flagd docs](https://flagd.dev/) for more information on flagd.

## sync-testbed container

The _sync_-testbed_ container is a docker image built on conforming to the sync.proto - a grpc which flagd or flagd in-process providers can use as a sync-source.
It features an identical set of flags to the [flagd-testbed container](#flagd-testbed-container)

Test this from the command line with [grpcurl](https://github.com/fullstorydev/grpcurl) (requires you have a copy of [sync.proto](https://raw.githubusercontent.com/open-feature/schemas/main/protobuf/sync/v1/sync_service.proto) at `/path/to/proto/dir/`):

```shell
# request all flags
grpcurl -import-path '/path/to/proto/dir' -proto sync.proto -plaintext localhost:9090 sync.v1.FlagSyncService/FetchAllFlags
```

```shell
# open a stream for getting flag changes
grpcurl -import-path '/path/to/proto/dir' -proto sync.proto -plaintext localhost:9090 sync.v1.FlagSyncService/SyncFlags
```
