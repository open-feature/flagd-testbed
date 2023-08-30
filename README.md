# OpenFeature Test Harness

This repository contains a docker image to support the [gherkin suites](https://github.com/open-feature/spec/blob/main/specification/appendix-b-gherkin-suites.md) in the OpenFeature specification.

## flagd-testbed container

The _flagd-testbed_ container is a docker image built on flagd, which essentially just adds a simple set of flags for the purposes of testing OpenFeature SDKs.
`testing-flags.json` contains a set of flags consistent with the [evaluation feature](https://github.com/open-feature/spec/blob/main/specification/assets/gherkin/evaluation.feature).
`change-flag.sh` runs in the test container generates a file `changing-flag.json`, which contains a flag that changes once every seconds, allowing to easily test change events.