// Package testbed ships the flagd-testbed assets - the docker-compose stack, the
// Gherkin suites, the flag definitions and the test root certificate - as embedded
// files.
//
// It exists so that Go test suites can depend on a released testbed through go.mod
// instead of a git submodule, which in turn allows test frameworks built on top of
// the testbed to be distributed as ordinary Go modules.
//
// The embedded compose file defaults to the flagd-testbed image of the release it
// was taken from, so the assets and the container image cannot drift apart:
//
//	dir := t.TempDir()
//	composePath, err := testbed.Materialize(dir)
package testbed

import (
	"embed"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// The ssl directory is embedded file by file on purpose: custom-ca.key is only
// needed to build the image and has no business being shipped to consumers.
//
//go:embed docker-compose.yaml version.txt gherkin flags ssl/custom-root-cert.crt
var assets embed.FS

const (
	// ComposeFileName is the name of the compose file, relative to the directory
	// passed to Materialize.
	ComposeFileName = "docker-compose.yaml"

	// CACertFile is the path of the root certificate flagd is served with in the
	// TLS configurations, relative to the directory passed to Materialize.
	CACertFile = "ssl/custom-root-cert.crt"
)

// FS returns all embedded assets, laid out exactly like the repository.
func FS() fs.FS {
	return assets
}

// Gherkin returns the Gherkin suites, rooted at the gherkin directory. It can be
// handed to godog as Options.FS, which avoids writing the suites to disk at all.
func Gherkin() fs.FS {
	return sub("gherkin")
}

// Flags returns the flag definitions, rooted at the flags directory. The testbed
// image carries these as well; they are embedded for suites that need to inspect
// or serve the definitions themselves.
func Flags() fs.FS {
	return sub("flags")
}

// ComposeYAML returns the raw compose file, for compose runners that accept the
// stack as a reader rather than a path.
func ComposeYAML() []byte {
	return mustRead(ComposeFileName)
}

// Version reports the flagd-testbed release the embedded assets were taken from,
// without the leading "v".
//
// Between releases - when the module is consumed at a pseudo-version - this is the
// version of the preceding release, matching the image the compose file defaults to.
func Version() string {
	return strings.TrimSpace(string(mustRead("version.txt")))
}

// Materialize writes the embedded assets into dir, creating it if needed, and
// returns the path of the compose file. Compose runners need the stack on disk,
// and the compose file resolves its default flags volume relative to its own
// location, so the assets have to travel together.
func Materialize(dir string) (string, error) {
	err := fs.WalkDir(assets, ".", func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		target := filepath.Join(dir, filepath.FromSlash(path))
		if entry.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		content, err := assets.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(target, content, 0o644)
	})
	if err != nil {
		return "", fmt.Errorf("materializing testbed assets into %s: %w", dir, err)
	}

	return filepath.Join(dir, ComposeFileName), nil
}

func sub(dir string) fs.FS {
	subFS, err := fs.Sub(assets, dir)
	if err != nil {
		// Unreachable: the directory is embedded above.
		panic(err)
	}

	return subFS
}

func mustRead(name string) []byte {
	content, err := assets.ReadFile(name)
	if err != nil {
		// Unreachable: the file is embedded above.
		panic(err)
	}

	return content
}
