// Command devcontainer generates project configurations sharing host Git and agent state.
package main

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

//go:embed delta.Dockerfile
var deltaDockerfile string

type profile struct {
	Image, Packages string
	Extensions      []string
}
type agent struct {
	Package string
	Paths   []string
}
type mount struct {
	Type     string `json:"type"`
	Source   string `json:"source"`
	Target   string `json:"target"`
	ReadOnly bool   `json:"readOnly"`
}

func exists(path string) bool { _, err := os.Stat(path); return err == nil }
func isDir(path string) bool  { info, err := os.Stat(path); return err == nil && info.IsDir() }
func quote(s string) string   { return "'" + strings.ReplaceAll(s, "'", "'\"'\"'") + "'" }
func symlink(path string) bool {
	info, err := os.Lstat(path)
	return err == nil && info.Mode()&os.ModeSymlink != 0
}

func selectAgents(selection, home string) ([]string, error) {
	result := []string{}
	candidates := strings.Split(selection, ",")
	if selection == "none" {
		return result, nil
	}
	if selection == "auto" {
		candidates = nil
		for name := range agents {
			candidates = append(candidates, name)
		}
		sort.Strings(candidates)
	}
	seen := map[string]bool{}
	for _, name := range candidates {
		name = strings.TrimSpace(name)
		a, ok := agents[name]
		if !ok {
			return nil, fmt.Errorf("unknown agent %q", name)
		}
		available := true
		for _, path := range a.Paths {
			if !isDir(filepath.Join(home, path)) {
				available = false
			}
		}
		if selection == "auto" && !available {
			continue
		}
		if !seen[name] {
			result = append(result, name)
			seen[name] = true
		}
	}
	return result, nil
}

func generate(project, language, home string, selected []string, force bool) (string, error) {
	p, ok := profiles[language]
	if !ok {
		return "", fmt.Errorf("unknown language %q", language)
	}
	project, err := filepath.Abs(project)
	if err != nil {
		return "", err
	}
	project, err = filepath.EvalSymlinks(project)
	if err != nil {
		return "", err
	}
	home, err = filepath.Abs(home)
	if err != nil {
		return "", err
	}
	home, err = filepath.EvalSymlinks(home)
	if err != nil {
		return "", err
	}
	if !isDir(project) {
		return "", fmt.Errorf("project directory does not exist: %s", project)
	}
	if home == "/" || strings.ContainsAny(home, "\n\r$,\\\"") {
		return "", errors.New("unsupported host home path")
	}
	target := filepath.Join(project, ".devcontainer")
	if symlink(target) {
		return "", errors.New("refusing a symlinked .devcontainer directory")
	}
	if exists(target) && !force {
		return "", errors.New(".devcontainer already exists; use --force to replace generated files")
	}
	paths := []struct {
		path     string
		readonly bool
	}{{".gitconfig", true}, {".config/git", true}, {".gitignore_global", true}, {".config/ai", true}}
	claude := false
	for _, name := range selected {
		a, ok := agents[name]
		if !ok {
			return "", fmt.Errorf("unknown agent %q", name)
		}
		for _, path := range a.Paths {
			if !isDir(filepath.Join(home, path)) {
				return "", fmt.Errorf("missing host directory for %s: %s", name, filepath.Join(home, path))
			}
			paths = append(paths, struct {
				path     string
				readonly bool
			}{path, false})
		}
		if name == "claude" {
			claude = true
		}
	}
	if claude {
		paths = append(paths, struct {
			path     string
			readonly bool
		}{".claude.json", false})
	}
	mounts := []mount{}
	for _, item := range paths {
		if exists(filepath.Join(home, item.path)) {
			destination := filepath.Join(home, item.path)
			if item.path == ".gitconfig" {
				destination = "/run/host-gitconfig"
			}
			mounts = append(mounts, mount{"bind", "${localEnv:HOME}/" + item.path, destination, item.readonly})
		}
	}
	dockerfile := fmt.Sprintf("FROM %s\nUSER root\nRUN apt-get update && apt-get install -y --no-install-recommends \\\n    bash-completion ca-certificates curl fzf git git-lfs gnupg openssh-client ripgrep zoxide %s \\\n    && rm -rf /var/lib/apt/lists/*\n", p.Image, p.Packages)
	dockerfile += deltaDockerfile
	if home != "/home/vscode" {
		dockerfile += "RUN usermod --home " + quote(home) + " --move-home vscode\n"
	}
	// Docker ENV uses its own quoting syntax, rather than shell quoting.
	envHome, _ := json.Marshal(home)
	dockerfile += "ENV HOME=" + string(envHome) + "\n"
	if language == "python" {
		dockerfile += "RUN python -m pip install --no-cache-dir uv ruff ty\n"
	}
	if language == "infra" {
		dockerfile += "RUN python -m pip install --no-cache-dir ansible-core ansible-lint yamllint\n"
	}
	config := map[string]any{
		"name":       filepath.Base(project) + " — " + language,
		"build":      map[string]string{"dockerfile": "Dockerfile"},
		"remoteUser": "vscode", "updateRemoteUserUID": true,
		"containerEnv": map[string]string{"HOME": home}, "mounts": mounts,
		"customizations": map[string]any{"vscode": map[string]any{"extensions": p.Extensions}},
	}
	if len(selected) > 0 {
		packages := []string{}
		for _, name := range selected {
			packages = append(packages, quote(agents[name].Package))
		}
		config["postCreateCommand"] = "sudo npm install --global --no-audit --no-fund " + strings.Join(packages, " ")
		if language != "node" {
			config["features"] = map[string]any{"ghcr.io/devcontainers/features/node:1": map[string]string{"version": "22"}}
		}
	}
	if claude {
		config["remoteEnv"] = map[string]string{"ANTHROPIC_AUTH_TOKEN": "${localEnv:ANTHROPIC_AUTH_TOKEN}"}
	}
	dockerfile += "USER vscode\n"
	if exists(filepath.Join(home, ".gitconfig")) {
		dockerfile += "RUN git config --global include.path /run/host-gitconfig\n"
	}
	var data bytes.Buffer
	encoder := json.NewEncoder(&data)
	encoder.SetEscapeHTML(false)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(config); err != nil {
		return "", err
	}
	files := []struct{ name, content string }{{"Dockerfile", dockerfile}, {"devcontainer.json", data.String()}}
	// Validate every output before replacing any file.
	for _, file := range files {
		path := filepath.Join(target, file.name)
		if info, err := os.Lstat(path); err == nil {
			if !info.Mode().IsRegular() {
				return "", fmt.Errorf("refusing non-regular output: %s", path)
			}
		} else if !os.IsNotExist(err) {
			return "", err
		}
	}
	if err := os.MkdirAll(target, 0755); err != nil {
		return "", err
	}
	for _, file := range files {
		if err := writeAtomic(filepath.Join(target, file.name), file.content); err != nil {
			return "", err
		}
	}
	return target, nil
}

func writeAtomic(path, content string) error {
	file, err := os.CreateTemp(filepath.Dir(path), ".devcontainer-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	if _, err = io.WriteString(file, content); err != nil {
		file.Close()
		return err
	}
	if err = file.Chmod(0644); err != nil {
		file.Close()
		return err
	}
	if err = file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), path)
}

func run(args []string, home string, out, stderr io.Writer) error {
	flags := flag.NewFlagSet("devcontainer", flag.ContinueOnError)
	flags.SetOutput(stderr)
	language := flags.String("language", "", "c-cpp, go, rust, python, node, java, infra (required)")
	selection := flags.String("agents", "auto", "auto, none, or comma-separated codex,cline,opencode,claude,gemini")
	force := flags.Bool("force", false, "Replace the two generated files")
	flags.Usage = func() {
		fmt.Fprintln(stderr, "Usage: devcontainer PROJECT --language LANGUAGE [--agents AGENTS] [--force]")
		flags.PrintDefaults()
	}
	// Accept the project's original position before the flags as well as flags first.
	if len(args) > 0 && !strings.HasPrefix(args[0], "-") {
		args = append(append([]string{}, args[1:]...), args[0])
	}
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 1 || *language == "" {
		flags.Usage()
		return errors.New("one project and --language are required")
	}
	selected, err := selectAgents(*selection, home)
	if err != nil {
		return err
	}
	target, err := generate(flags.Arg(0), *language, home, selected, *force)
	if err != nil {
		return err
	}
	names := strings.Join(selected, ", ")
	if names == "" {
		names = "none"
	}
	fmt.Fprintf(out, "Created %s; agents: %s\n", target, names)
	fmt.Fprintln(out, "Open the project in VS Code and choose Dev Containers: Reopen in Container.")
	return nil
}

func main() {
	home, err := os.UserHomeDir()
	if err == nil {
		err = run(os.Args[1:], home, os.Stdout, os.Stderr)
	}
	if errors.Is(err, flag.ErrHelp) {
		return
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
