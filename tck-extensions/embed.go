// Package tckextensions carries the flagd Provider TCK extension scenarios as a
// Go module, so a Go flagd adoption can pin a revision of them in go.mod.
//
// Other languages read this directory through a git submodule. A Go module zip
// carries a submodule only as a gitlink, without its files, so Go gets the same
// bytes through this module instead. It holds no code beyond this file and has
// no dependencies. See https://github.com/open-feature/spec/issues/417.
package tckextensions

import "embed"

// FS holds the extension feature files, keyed by file name.
//
//go:embed *.feature
var FS embed.FS
