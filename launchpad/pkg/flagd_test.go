package flagd

import (
	"os"
	"path/filepath"
	"testing"
)

// writeConfig writes a flagd configuration to a temporary file and returns its
// path.
func writeConfig(t *testing.T, body string) string {
	t.Helper()

	path := filepath.Join(t.TempDir(), "config.json")
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatalf("failed to write config: %v", err)
	}
	return path
}

func TestFileSources(t *testing.T) {
	tests := []struct {
		name string
		body string
		want []string
	}{
		{
			name: "file sources are returned in order",
			body: `{"sources":[{"uri":"flags/allFlags.json","provider":"file"},{"uri":"rawflags/selector-flags.json","provider":"file"}]}`,
			want: []string{"flags/allFlags.json", "rawflags/selector-flags.json"},
		},
		{
			name: "non-file providers are skipped",
			body: `{"sources":[{"uri":"http://example.com","provider":"http"},{"uri":"flags/allFlags.json","provider":"file"}]}`,
			want: []string{"flags/allFlags.json"},
		},
		{
			name: "a configuration without sources yields none",
			body: `{}`,
			want: nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := fileSources(writeConfig(t, tt.body))
			if err != nil {
				t.Fatalf("fileSources returned an error: %v", err)
			}
			if len(got) != len(tt.want) {
				t.Fatalf("got %v, want %v", got, tt.want)
			}
			for i := range got {
				if got[i] != tt.want[i] {
					t.Fatalf("got %v, want %v", got, tt.want)
				}
			}
		})
	}
}

func TestFileSourcesRejectsUnreadableAndInvalidConfigs(t *testing.T) {
	if _, err := fileSources(filepath.Join(t.TempDir(), "missing.json")); err == nil {
		t.Fatal("expected an error for a missing configuration")
	}
	if _, err := fileSources(writeConfig(t, "not json")); err == nil {
		t.Fatal("expected an error for an unparseable configuration")
	}
}

// TestServesCombinedFlags covers the distinction the restore path depends on:
// changing-flag only reaches flagd through the merged flag file, so a
// configuration that does not read it can never serve the flag and must not be
// waited on.
func TestServesCombinedFlags(t *testing.T) {
	tests := []struct {
		name string
		body string
		want bool
	}{
		{
			name: "the default shape reads the merged file",
			body: `{"sources":[{"uri":"flags/allFlags.json","provider":"file"},{"uri":"rawflags/selector-flags.json","provider":"file"}]}`,
			want: true,
		},
		{
			name: "the merged file is recognised through an unclean path",
			body: `{"sources":[{"uri":"./flags/allFlags.json","provider":"file"}]}`,
			want: true,
		},
		{
			name: "the metadata shape does not",
			body: `{"sources":[{"uri":"rawflags/selector-flag-combined-metadata.json","provider":"file"}]}`,
			want: false,
		},
		{
			name: "an unreadable configuration does not",
			body: `not json`,
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := servesCombinedFlags(writeConfig(t, tt.body)); got != tt.want {
				t.Fatalf("got %v, want %v", got, tt.want)
			}
		})
	}
}
