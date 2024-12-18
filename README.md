# OpenFeature Test Harness

This repository contains a docker image to support the [gherkin suites](https://github.com/open-feature/spec/blob/main/specification/appendix-b-gherkin-suites.md) in the OpenFeature specification.

## flagd-testbed container

The _flagd-testbed_ container is a docker image built on flagd, which essentially just adds a simple set of flags for the purposes of testing OpenFeature SDKs.
`testing-flags.json` contains a set of flags consistent with the [evaluation feature](https://github.com/open-feature/spec/blob/main/specification/assets/gherkin/evaluation.feature).
`change-flag.sh` runs in the test container generates a file `changing-flag.json`, which contains a flag that changes once every seconds, allowing to easily test change events.

See the [flagd docs](https://flagd.dev/) for more information on flagd.

### SSL

The _flagd-testbed-ssl_ container is based on _flagd-testbed_ but replaces all the certificates for SSL testing with a custom root CA.
Within the SSL folder you will find all the necessary OpenSSL files, and the commands used for generation.
Please do not use this CA in any kind of production environment.

## Gherkin test suite

The [gherkin/](gherkin/) dir includes a set of [_gherkin_](https://cucumber.io/docs/gherkin/) tests that define expected behavior associated with the configurations defined in the flagd-testbed (see [flags/](flags/)).
Combined with the _flagd-provider_ for the associated SDK and the flagd-testbed, these comprise a complete integration test suite.

Included suites:

[flagd.feature](gherkin/flagd.feature) includes tests relevant to flagd and all flagd providers:
* default value (zero-value) handling (some proto3 implementations handle these inconsistently).
* basic event handling

[flagd-json-evaluator.feature](gherkin/flagd-json-evaluator.feature) includes tests relevant to flagd and in-process providers:
* custom JSONLogic operators (`starts_with`, `ends_with`, `fractional`, `sem_ver`)
* evaluator reuse via `$ref`


### Lint Gherkin files

The Gherkin files structure can be linted using [gherkin-lint](https://github.com/vsiakka/gherkin-lint). The following commands require Node.js 10 or later.

1. npm install
1. npm run gherkin-lint

