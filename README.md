# OpenFeature Test Harness

This repository contains the makings of an integration test suite for OpenFeature SDKs.

## flagd-testbed container

The _flagd-testbed_ container is a docker image built on flagd, which essentially just adds a simple set of flags for the purposes of testing OpenFeature SDKs.

## Cucumber test suite

The cucumber test suite is a set of [_cucumber_](https://cucumber.io/) tests that define expected behavior associated with the flags defined in the flagd-testbed. Combined with the _flagd-provider_ for that SDK and the flagd-testbed, these comprise a complete integration tests suite.