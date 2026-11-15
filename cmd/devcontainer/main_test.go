package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func setup(t *testing.T) (string, string) {
	t.Helper()
	root := t.TempDir()
	home, project := filepath.Join(root, "host home"), filepath.Join(root, "project with spaces")
	for _, path := range []string{home, project} {
		if err := os.MkdirAll(path, 0755); err != nil {
			t.Fatal(err)
		}
	}
	return home, project
}
func read(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}
func put(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0600); err != nil {
		t.Fatal(err)
	}
}

func TestProfiles(t *testing.T) {
	for name := range profiles {
		t.Run(name, func(t *testing.T) {
			home, project := setup(t)
			target, err := generate(project, name, home, nil, false)
			if err != nil {
				t.Fatal(err)
			}
			var config map[string]any
			if err := json.Unmarshal([]byte(read(t, filepath.Join(target, "devcontainer.json"))), &config); err != nil {
				t.Fatal(err)
			}
			if config["containerEnv"].(map[string]any)["HOME"] != home {
				t.Fatal("wrong home")
			}
			if _, ok := config["postCreateCommand"]; ok {
				t.Fatal("unexpected agent install")
			}
			dockerfile := read(t, filepath.Join(target, "Dockerfile"))
			if !strings.HasPrefix(dockerfile, "FROM "+profiles[name].Image+"\n") || !strings.HasSuffix(dockerfile, "USER vscode\n") {
				t.Fatal("wrong Dockerfile")
			}
		})
	}
}
func TestSharedConfig(t *testing.T) {
	home, project := setup(t)
	put(t, filepath.Join(home, ".codex/auth.json"), "secret-value")
	put(t, filepath.Join(home, ".gitconfig"), "[user]\nname = Test\n")
	target, err := generate(project, "python", home, []string{"codex"}, false)
	if err != nil {
		t.Fatal(err)
	}
	configText := read(t, filepath.Join(target, "devcontainer.json"))
	dockerfile := read(t, filepath.Join(target, "Dockerfile"))
	if strings.Contains(configText+dockerfile, "secret-value") {
		t.Fatal("credential leaked")
	}
	var config struct {
		Mounts            []mount
		PostCreateCommand string
		Features          map[string]any
	}
	if err := json.Unmarshal([]byte(configText), &config); err != nil {
		t.Fatal(err)
	}
	foundGit, foundAgent := false, false
	for _, m := range config.Mounts {
		if m.Target == "/run/host-gitconfig" {
			foundGit = m.ReadOnly
		}
		if m.Target == filepath.Join(home, ".codex") {
			foundAgent = !m.ReadOnly
		}
	}
	if !foundGit || !foundAgent || !strings.Contains(dockerfile, "include.path /run/host-gitconfig") {
		t.Fatal("incorrect sharing")
	}
	if !strings.Contains(config.PostCreateCommand, "@openai/codex") || len(config.Features) == 0 {
		t.Fatal("missing CLI or Node feature")
	}
}
func TestOverwriteAndSymlinks(t *testing.T) {
	home, project := setup(t)
	target, err := generate(project, "go", home, nil, false)
	if err != nil {
		t.Fatal(err)
	}
	before := read(t, filepath.Join(target, "Dockerfile"))
	if _, err := generate(project, "rust", home, nil, false); err == nil {
		t.Fatal("overwrote existing configuration")
	}
	path := filepath.Join(target, "devcontainer.json")
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	victim := filepath.Join(home, "victim")
	put(t, victim, "keep")
	if err := os.Symlink(victim, path); err != nil {
		t.Fatal(err)
	}
	if _, err := generate(project, "rust", home, nil, true); err == nil {
		t.Fatal("accepted symlink")
	}
	if read(t, victim) != "keep" || read(t, filepath.Join(target, "Dockerfile")) != before {
		t.Fatal("changed files before rejecting symlink")
	}
}
func TestInvalidInputs(t *testing.T) {
	for _, kind := range []string{"agent", "language", "missing-directory", "home", "target-symlink"} {
		t.Run(kind, func(t *testing.T) {
			home, project := setup(t)
			language := "go"
			var selected []string
			switch kind {
			case "agent":
				selected = []string{"codex"}
			case "language":
				language = "unknown"
			case "missing-directory":
				project = filepath.Join(project, "missing")
			case "home":
				home = "/"
			case "target-symlink":
				if err := os.Symlink(home, filepath.Join(project, ".devcontainer")); err != nil {
					t.Fatal(err)
				}
			}
			if _, err := generate(project, language, home, selected, true); err == nil {
				t.Fatal("invalid input accepted")
			}
			if exists(filepath.Join(project, ".devcontainer/Dockerfile")) {
				t.Fatal("wrote invalid configuration")
			}
		})
	}
}
func TestAgentSelection(t *testing.T) {
	home, _ := setup(t)
	put(t, filepath.Join(home, ".codex/config.toml"), "")
	got, err := selectAgents("auto", home)
	if err != nil || strings.Join(got, ",") != "codex" {
		t.Fatalf("auto: %v %v", got, err)
	}
	got, err = selectAgents("codex,codex", home)
	if err != nil || len(got) != 1 {
		t.Fatal("duplicate agents")
	}
	if _, err := selectAgents("invalid", home); err == nil {
		t.Fatal("unknown agent accepted")
	}
}
func TestCLI(t *testing.T) {
	for _, first := range []bool{true, false} {
		t.Run(map[bool]string{true: "project-first", false: "flags-first"}[first], func(t *testing.T) {
			home, project := setup(t)
			args := []string{"--language", "go", "--agents", "none", project}
			if first {
				args = []string{project, "--language", "go", "--agents", "none"}
			}
			var out bytes.Buffer
			if err := run(args, home, &out, &out); err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(out.String(), "agents: none") {
				t.Fatal("missing output")
			}
		})
	}
}
