# OpenFeature Test Harness

This repository contains the makings of an end-to-end test suite for OpenFeature SDKs.

## flagd-testbed container

The _flagd-testbed_ container is a docker image built on flagd, which essentially just adds a simple set of flags for the purposes of testing OpenFeature SDKs.

## Gherkin test suite

The test suite is a set of [_gherkin_](https://cucumber.io/docs/gherkin/) tests that define expected behavior associated with the flags defined in the flagd-testbed. Combined with the _flagd-provider_ for that SDK and the flagd-testbed, these comprise a complete end-to-end tests suite.

### Lint Gherkin files

The Gherkin files structure can be linted using [gherkin-lint](https://github.com/vsiakka/gherkin-lint). The following commands require Node.js 10 or later.

1. npm install
1. npm run gherkin-lint
