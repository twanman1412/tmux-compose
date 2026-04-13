# tmux-compose

# tmux-compose

`tmux-compose` is a small C utility that makes `docker-compose` + `tmux` feel like one tool.
It starts your compose stack and opens each container in its own tmux pane so you can watch logs and interact with services from a single workspace.

This project is also a personal playground for trying out and refining new AI-powered tools in my Neovim setup.

## Features

- Open each running compose container in a dedicated tmux pane
- Keep your whole stack visible in one terminal session
- Fast keybinds for common container actions from the focused pane:
  - restart container
  - stop container
  - execute a command
  - open a shell
- Lightweight single-binary implementation in C

## Why tmux-compose?

When working on multi-service apps, constantly switching between terminals and container commands is noisy and slow. `tmux-compose` gives you a focused, pane-based view of your whole stack and quick controls for day-to-day container tasks.

## Requirements

- `tmux`
- `docker`
- `docker-compose` (or Docker Compose plugin compatibility, depending on your setup)
- A Unix-like environment

## Build

Use the provided Makefile to compile the project:

```bash
make
```

Optional cleanup:

```bash
make clean
```

Adjust source file names/flags in the Makefile as needed for your local tree.
## Usage

Run from a directory containing your compose file:

```bash
./tmux-compose
```

Typical flow:

1. Run `./tmux-compose` (optionally with `docker-compose` flags)
2. `tmux-compose` starts your compose stack with those flags
3. `tmux-compose` automatically creates/attaches the tmux session and opens the container panes

## Keybinds

The exact bindings are configurable/implementation-specific, but the core actions are:

- restart focused container
- stop focused container
- run a custom command in focused container
- open an interactive shell in focused container

If you want, this section can be updated with the exact default mappings from the source.

## Project Goals

- Make local multi-container development smoother
- Keep a minimal, hackable C codebase
- Validate and improve AI-assisted Neovim workflows in real development tasks

## Status

Early-stage utility; expect iterative improvements and changing defaults.

## License

MIT License. See LICENSE file for details.
