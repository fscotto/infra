# Deployed global AI context

The standing AI context for this user is deployed by the Ansible-managed
dotfiles under `~/.config/ai/` and is maintained in the infrastructure
repository. Cline binds to it automatically in every project through this
global rule.

- Operating context: read `~/.config/ai/bootstrap.md` first. It carries the
  persistent mental model: core principles, system and infrastructure models,
  and agent behavior.
- Safety directives: apply `~/.config/ai/rules/safety.md`.
- Task-specific loading: follow the dispatcher `~/.config/ai/AGENTS.md` and
  read only the files relevant to the current task from `knowledge/`, `rules/`,
  and `patterns/`. Do not preemptively load all task-specific files.
- Distilled knowledge: for prior decisions, history, and stable preferences,
  start from `~/.config/ai/memory/chatgpt/INDEX.md` and read the matching
  topic file under `~/.config/ai/memory/chatgpt/knowledge/`. When that is not
  enough, search the full transcripts with
  `rg -i "<keyword>" ~/.config/ai/memory/chatgpt/transcripts/`.

These deployed files are managed state: never record session-specific notes in
them. Update them in the source infrastructure repository instead, so the next
playbook run converges the change everywhere.
