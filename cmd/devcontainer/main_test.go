package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
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

type vscodeCustomizations struct {
	Customizations struct {
		Vscode struct {
			Extensions []string `json:"extensions"`
		} `json:"vscode"`
	} `json:"customizations"`
}

func extensionsOf(t *testing.T, target string) []string {
	t.Helper()
	var config vscodeCustomizations
	if err := json.Unmarshal([]byte(read(t, filepath.Join(target, "devcontainer.json"))), &config); err != nil {
		t.Fatal(err)
	}
	return config.Customizations.Vscode.Extensions
}

func TestProfiles(t *testing.T) {
	for name := range profiles {
		t.Run(name, func(t *testing.T) {
			home, project := setup(t)
			target, err := generate(project, name, home, nil, nil, false)
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
			want := append([]string{}, profiles[name].Extensions...)
			slices.Sort(want)
			if got := extensionsOf(t, target); !slices.Equal(got, want) {
				t.Fatalf("wrong extensions: %v", got)
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
	target, err := generate(project, "python", home, []string{"codex"}, nil, false)
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
	if !strings.Contains(config.PostCreateCommand, "@openai/codex") || !strings.Contains(dockerfile, "COPY --from=node /usr/local/bin/node") {
		t.Fatal("missing CLI install or embedded Node")
	}
	if !slices.Contains(extensionsOf(t, target), "openai.chatgpt") {
		t.Fatal("agent VS Code extension missing")
	}
}
func TestAgentAndLocalExtensions(t *testing.T) {
	home, project := setup(t)
	put(t, filepath.Join(home, ".cline/state/config"), "")
	put(t, filepath.Join(home, ".agents/AGENTS.md"), "")
	local := []string{"github.remotehub", "SAOUDRIZWAN.claude-dev", "ms-vscode.cpptools"}
	target, err := generate(project, "python", home, []string{"cline"}, local, false)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"ms-python.python", "charliermarsh.ruff", "saoudrizwan.claude-dev", "github.remotehub", "ms-vscode.cpptools"}
	slices.Sort(want)
	if got := extensionsOf(t, target); !slices.Equal(got, want) {
		t.Fatalf("extensions mismatch: %v", got)
	}
}
func TestAgentsShipNpmInsideSudoPath(t *testing.T) {
	for name := range profiles {
		t.Run(name, func(t *testing.T) {
			home, project := setup(t)
			put(t, filepath.Join(home, ".cline/state/config"), "")
			put(t, filepath.Join(home, ".agents/AGENTS.md"), "")
			target, err := generate(project, name, home, []string{"cline"}, nil, false)
			if err != nil {
				t.Fatal(err)
			}
			var config map[string]any
			if err := json.Unmarshal([]byte(read(t, filepath.Join(target, "devcontainer.json"))), &config); err != nil {
				t.Fatal(err)
			}
			if _, hasFeature := config["features"]; hasFeature {
				t.Fatal("the nvm-based node feature breaks the sudo npm postCreateCommand")
			}
			post, _ := config["postCreateCommand"].(string)
			if !strings.Contains(post, "sudo npm install") {
				t.Fatalf("missing npm agent install: %q", post)
			}
			dockerfile := read(t, filepath.Join(target, "Dockerfile"))
			if !strings.HasPrefix(dockerfile, "FROM docker.io/library/node:22-bookworm-slim AS node\n") ||
				!strings.Contains(dockerfile, "COPY --from=node /usr/local/bin/node /usr/local/bin/node") ||
				!strings.Contains(dockerfile, "ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm") {
				t.Fatal("npm must be reachable inside sudo's secure_path")
			}
		})
	}
}
func TestOverwriteAndSymlinks(t *testing.T) {
	home, project := setup(t)
	target, err := generate(project, "go", home, nil, nil, false)
	if err != nil {
		t.Fatal(err)
	}
	before := read(t, filepath.Join(target, "Dockerfile"))
	if _, err := generate(project, "rust", home, nil, nil, false); err == nil {
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
	if _, err := generate(project, "rust", home, nil, nil, true); err == nil {
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
			if _, err := generate(project, language, home, selected, nil, true); err == nil {
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
func TestLocalExtensionDiscovery(t *testing.T) {
	bin := t.TempDir()
	script := filepath.Join(bin, "code")
	if err := os.WriteFile(script, []byte("#!/bin/sh\necho a.b\necho c.d\n"), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	home, project := setup(t)
	var out bytes.Buffer
	if err := run([]string{project, "--language", "go", "--agents", "none"}, home, &out, &out); err != nil {
		t.Fatal(err)
	}
	want := []string{"a.b", "c.d", "golang.go"}
	slices.Sort(want)
	if got := extensionsOf(t, filepath.Join(project, ".devcontainer")); !slices.Equal(got, want) {
		t.Fatalf("extensions mismatch: %v", got)
	}
	if !strings.Contains(out.String(), "Included 2 local VS Code extensions.") {
		t.Fatal("missing local extensions summary")
	}
}
