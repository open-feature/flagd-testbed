# TCK extensions

The scenarios in `gherkin/`, rewritten as extensions for the
[OpenFeature Provider TCK](https://github.com/open-feature/spec/issues/417). A flagd provider that
adopts the TCK runs these alongside the TCK's own scenarios, instead of running `gherkin/` through a
harness of its own.

They ask only what the TCK's canonical scenarios do not. Each file's header names its source feature,
the scenarios it leaves out, and why; most of those the TCK already asks.

They are written in the TCK's step vocabulary (`a stable provider`, `a context with the following
keys:`), plus flagd-specific steps an adopter supplies as extension glue: provider options
(`an option "<name>" of type "<type>" with value "<value>"`) and connection control. Feature tags
name the resolvers a scenario applies to (`@rpc`, `@in-process`, `@file`), as in `gherkin/`.

`gherkin/` stays as it is for SDKs that still run it directly. A scenario added there should be
added here too, or listed as not ported in the matching file's header.
