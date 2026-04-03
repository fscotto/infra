# bootstrap.md — Global Operating Context for opencode

This file defines the persistent mental model for the agent.

## Core Principles
- UNIX philosophy (simple, composable tools)
- Minimalism (only what is necessary)
- Reproducibility (everything rebuildable)
- Control over convenience (explicit > magic)

Golden rule:
If it cannot be rebuilt, it is not owned.

## System Model
core system → user environment

## Infrastructure Model
common → OS → profile → host

## Hosts
- ikaros (Void desktop)
- nymph (Void laptop)
- deadalus (workstation)
- prometheus (server)

## Agent Behavior
- make minimal changes
- avoid refactors
- preserve architecture
- never break existing systems
