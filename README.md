# Flagd Test Harness

This repository contains a Docker image and flagd's [Provider TCK](https://github.com/open-feature/spec/issues/417) extension scenarios, which flagd providers run to check their behaviour.

## `flagd-testbed` Container

The **`flagd-testbed`** container is a Docker image that includes [**flagd**](https://flagd.dev/) and a testing utility called **launchpad**.
It provides a simple way to run end-to-end (E2E) tests across multiple SDKs.

### Launchpad

**Launchpad** is a control center for managing flagd during tests.
It exposes a REST interface that allows you to:

* Start, stop, or restart flagd
* Dynamically update a single flag, simulating real-time flag changes

This approach centralizes the test orchestration logic, reducing the need to replicate it across SDKs in multiple languages. This simplifies test implementation and allows contributors to focus on testing behavior rather than setup.

#### REST API & Development Docs

Detailed usage and API documentation can be found in the [Launchpad README](./launchpad/README.md).

#### Storing Configurations

Flagd configurations are stored in the [`launchpad/configs`](./launchpad/configs) directory.
Each file corresponds to a named configuration and can be passed as a parameter to the `start` endpoint.

Configurations may include different types of flagd setups and flag files.

### Flag Files

Configured flag definitions reside in the [`flags`](./flags) directory.
Within the Docker image:

* The contents of this directory are mounted under `/rawflags`
* A generated file, `/flags/allFlags.json`, aggregates all flag files **excluding** those prefixed with `selector`

This file is generated when flagd is started and can be used to test all flags in file mode simultaneously.

---

## TCK Extensions

The [`tck-extensions`](./tck-extensions) directory holds flagd's scenarios as extensions for the
[OpenFeature Provider TCK](https://github.com/open-feature/spec/issues/417): a flagd provider runs
them alongside the TCK's own scenarios, against the image above. Its
[README](./tck-extensions/README.md) covers the tags, the extension steps and how to consume it.

The legacy `gherkin/` suite was removed in 4.0. SDKs that still run it pin a 3.x release, which
keeps being cut from the [`release/v3`](https://github.com/open-feature/flagd-testbed/tree/release/v3)
branch.

---

## How to utilize?

This repository should be included as a submodule within your sdk which should be tested.

We recommend:
- to setup renovate to automatically update your submodule, always pointing to version tags and not branches
- to load all extension feature files, and eliminate tests via tag exclusions
- to utilize testcontainers for easier test setup
- to use the version.txt within this repository to load the appropriate docker image

---

## Building the Docker Image

The `flagd-testbed` Docker image can be built from the Dockerfile located at `flagd/Dockerfile`.

### Basic Build

To build the image with the default flagd base image:

```bash
docker build -f flagd/Dockerfile -t flagd-testbed:latest --target testbed .
```

### Custom Base Image

You can specify a custom flagd base image using the `FLAGD_BASE_IMAGE` build argument. This is useful when testing with pipeline-built or custom flagd images:

```bash
docker build -f flagd/Dockerfile \
  --build-arg FLAGD_BASE_IMAGE=ghcr.io/open-feature/flagd:custom-tag \
  -t flagd-testbed:custom --target testbed .
```

**Examples:**

```bash
# Using a specific flagd version
docker build -f flagd/Dockerfile \
  --build-arg FLAGD_BASE_IMAGE=ghcr.io/open-feature/flagd:v0.13.0 \
  -t flagd-testbed:v0.13.0 --target testbed .

# Using a locally built flagd image
docker build -f flagd/Dockerfile \
  --build-arg FLAGD_BASE_IMAGE=my-custom-flagd:latest \
  -t flagd-testbed:dev --target testbed .
```

If the `FLAGD_BASE_IMAGE` argument is not provided, the build defaults to `ghcr.io/open-feature/flagd:v0.12.9` to maintain backwards compatibility.

---

### Linting Gherkin Files

You can lint the Gherkin file structure using [gherkin-lint](https://github.com/vsiakka/gherkin-lint).
Requires Node.js v10+.

```bash
npm install
npm run gherkin-lint
```

