package main

var profiles = map[string]profile{
	"c-cpp":  {Image: "mcr.microsoft.com/devcontainers/base:bookworm", Packages: "build-essential clang clangd cmake gdb valgrind universal-ctags cscope", Extensions: []string{"ms-vscode.cpptools", "ms-vscode.cmake-tools"}},
	"go":     {Image: "mcr.microsoft.com/devcontainers/go:1.25-bookworm", Packages: "", Extensions: []string{"golang.go"}},
	"rust":   {Image: "mcr.microsoft.com/devcontainers/rust:1-bookworm", Packages: "", Extensions: []string{"rust-lang.rust-analyzer"}},
	"python": {Image: "mcr.microsoft.com/devcontainers/python:3.13-bookworm", Packages: "", Extensions: []string{"ms-python.python", "charliermarsh.ruff"}},
	"node":   {Image: "mcr.microsoft.com/devcontainers/javascript-node:22-bookworm", Packages: "", Extensions: []string{"esbenp.prettier-vscode"}},
	"java":   {Image: "mcr.microsoft.com/devcontainers/java:21-bookworm", Packages: "maven", Extensions: []string{"vscjava.vscode-java-pack"}},
	"infra":  {Image: "mcr.microsoft.com/devcontainers/python:3.13-bookworm", Packages: "shellcheck shfmt", Extensions: []string{"redhat.ansible", "redhat.vscode-yaml"}},
}
var agents = map[string]agent{
	"codex":    {Package: "@openai/codex", Paths: []string{".codex"}},
	"cline":    {Package: "cline", Paths: []string{".cline", ".agents"}},
	"opencode": {Package: "opencode-ai", Paths: []string{".config/opencode", ".local/share/opencode", ".local/state/opencode"}},
	"claude":   {Package: "@anthropic-ai/claude-code@2.1.312", Paths: []string{".claude"}},
	"gemini":   {Package: "@google/gemini-cli", Paths: []string{".gemini"}},
}
