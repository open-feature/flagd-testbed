package testbed_test

import (
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"testing"

	testbed "github.com/open-feature/flagd-testbed/v3"
)

// The compose file and version.txt are stamped independently by release-please;
// a consumer pinning the module gets the wrong image if they ever disagree.
func TestComposeDefaultsToTheEmbeddedVersion(t *testing.T) {
	matches := regexp.MustCompile(`\$\{VERSION:-v([0-9]+\.[0-9]+\.[0-9]+)\}`).FindSubmatch(testbed.ComposeYAML())
	if matches == nil {
		t.Fatal("compose file has no ${VERSION:-vX.Y.Z} default")
	}

	if got, want := string(matches[1]), testbed.Version(); got != want {
		t.Errorf("compose defaults to image v%s, version.txt says %s", got, want)
	}
}

func TestMaterializeWritesTheStack(t *testing.T) {
	dir := t.TempDir()

	composePath, err := testbed.Materialize(dir)
	if err != nil {
		t.Fatalf("Materialize: %v", err)
	}

	if want := filepath.Join(dir, testbed.ComposeFileName); composePath != want {
		t.Errorf("compose path is %s, want %s", composePath, want)
	}

	for _, name := range []string{testbed.ComposeFileName, testbed.CACertFile, "flags/testing-flags.json", "gherkin/evaluation.feature"} {
		if _, err := os.Stat(filepath.Join(dir, filepath.FromSlash(name))); err != nil {
			t.Errorf("%s not materialized: %v", name, err)
		}
	}

	// Only the certificate travels, never the CA key that signs it.
	if _, err := os.Stat(filepath.Join(dir, "ssl", "custom-ca.key")); !os.IsNotExist(err) {
		t.Errorf("ssl/custom-ca.key must not be embedded, got %v", err)
	}
}

func TestGherkinIsUsableAsAnFS(t *testing.T) {
	features, err := fs.Glob(testbed.Gherkin(), "*.feature")
	if err != nil {
		t.Fatalf("Glob: %v", err)
	}

	// The suites are the reason SDKs consume this repository at all.
	if len(features) == 0 {
		t.Fatal("no feature files embedded")
	}
}
