# AGENTS.md — Global Context (dispatcher)

Always follow:
- minimal, targeted edits
- preserve layering
- avoid duplication
- validate before applying changes

Task-specific file loading:
- For general background on the user, the environment, and stable preferences, read `~/.config/ai/memory/chatgpt/knowledge/00-profilo.md`
- For infra or Ansible work, read `~/.config/ai/knowledge/infra.md` and `~/.config/ai/rules/ansible.md`
- For desktop work, read `~/.config/ai/knowledge/desktop.md`
- For dotfiles work, read `~/.config/ai/knowledge/dotfiles.md` and `~/.config/ai/patterns/dotfiles_layering.md`
- For system programming work, read `~/.config/ai/knowledge/system_programming.md`
- For prior ChatGPT discussion context (past decisions, history, preferences, projects), start from `~/.config/ai/memory/chatgpt/INDEX.md`, then read the matching topic file under `~/.config/ai/memory/chatgpt/knowledge/`; search the full transcripts with `rg -i "<keyword>" ~/.config/ai/memory/chatgpt/transcripts/`

Do not preemptively load all task-specific files. Load only the files relevant to the current task.

