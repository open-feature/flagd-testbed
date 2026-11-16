# TCK extensions

flagd's scenarios as extensions for the
[OpenFeature Provider TCK](https://github.com/open-feature/spec/issues/417). A flagd provider that
adopts the TCK runs these alongside the TCK's own scenarios. They replace the `gherkin/` suite,
which 4.0 removed; it lives on in the 3.x releases cut from `release/v3`.

They ask only what the TCK's canonical scenarios do not. Each file's header names its source feature,
the scenarios it leaves out, and why; most of those the TCK already asks.

They are written in the TCK's step vocabulary (`a stable provider`, `a context with the following
keys:`), plus flagd-specific steps an adopter supplies as extension glue: provider options
(`an option "<name>" of type "<type>" with value "<value>"`) and connection control. Feature tags
name the resolvers a scenario applies to (`@rpc`, `@in-process`, `@file`).

Java, JavaScript, Python and .NET read this directory through the `test-harness` submodule. Go
depends on it as a module, `github.com/open-feature/flagd-testbed/tck-extensions`, whose `FS`
embeds the feature files, because a Go module zip carries a submodule without its files.

A scenario fixed or added on `release/v3` should be added here too, or listed as not ported in the
matching file's header.
