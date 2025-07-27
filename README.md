# tmux-compose

A better way to use docker-compose in the terminal with tmux integration.

Instead of dealing with the chaotic merged output of `docker-compose up`, tmux-compose automatically organizes your container logs into separate tmux windows/panes and provides easy access to container shells.

## Features

- 🚀 **Organized Logs**: Each service gets its own tmux window or pane
- 🔧 **Easy Shell Access**: Configurable keybind to open shell in current container
- ⚙ **Highly Configurable**: JSON configuration for layouts, keybinds, and behavior
- 🔄 **Full docker-compose Compatibility**: All docker-compose commands work normally

## Quick Start

```bash
# Clone and install
git clone https://github.com/twanman1412/tmux-compose.git
cd tmux-compose
./install.sh

# Use in any docker-compose project
cd /path/to/your/project
tmux-compose up
```

## Usage

### Basic Commands

```bash
# Start services in tmux session
tmux-compose up

# Start with build
tmux-compose up --build

# Stop services and clean up tmux session
tmux-compose down

# Show running containers
tmux-compose ps

# View logs
tmux-compose logs web

# Open shell in service container
tmux-compose shell web

# Restart a specific service (or start if not running)
tmux-compose restart web
```

### Default Keybinds

- `Ctrl+B + Space`: Open shell in current service container (configurable)
- `Ctrl+B + R`: Restart current service container (or start if not running) (configurable)
- `Ctrl+B + 0-9`: Switch between service windows
- `Ctrl+B + arrow keys`: Navigate between panes
- `Ctrl+B + d`: Detach from tmux session

## Configuration

tmux-compose uses JSON configuration files with the following priority:

1. `./tmux-compose.json` (project-specific)
2. `~/.config/tmux-compose/config.json` (global)
3. Built-in defaults

### Configuration Options

```json
{
  "services": "window|pane",                 // How to organize services
  "services_panes": 4,                       // Max panes per window (0 = unlimited)
  "shell_access": "split|window",            // How to open container shells
  "shell_priority": ["bash", "sh", "ash"],   // Shell preference order
  "session_naming": "{project_name}",        // Session name template
  "session_cleanup": "quit|store|persist",   // What to do when containers stop
  "split_direction": "horizontal|vertical",  // Split direction for shells
  "keybinds": {
    "shell_access": "Space",                 // Keybind for shell access
    "restart_service": "r"                   // Keybind for service restart
  }
}
```

### Service Organization Modes

**Window Mode** (`"services": "window"`):
- Each service gets its own tmux window
- Use `Ctrl+B + number` to switch between services
- Better for fewer services or small screens

**Pane Mode** (`"services": "pane"`):
- Services are organized in panes within windows
- Use `services_panes` to control layout
- Great for projects with many services

### Session Cleanup Modes

- **quit**: Kill tmux session when containers stop
- **store**: Save logs to files and kill session (TODO)
- **persist**: Keep session running for log review

## Examples

See the `examples/` directory for sample configurations and docker-compose files.

## Installation

### Install Dependencies

**Arch:**
```bash
sudo pacman -S tmux docker-compose jq yq
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install tmux docker-compose jq python3-pip
pip3 install yq
```

**macOS:**
```bash
brew install tmux docker-compose jq
pip3 install yq
```

**Fedora:**
```bash
sudo dnf install tmux docker-compose jq python3-pip
pip3 install yq
```

### Install tmux-compose

### Automatic Installation

```bash
./install.sh [/path/to/install/dir]
```

Default install directory is `/usr/local/bin`.

### Manual Installation

1. Copy `tmux-compose` to your PATH
2. Copy `lib/` directory alongside the script
3. Create config directory: `mkdir -p ~/.config/tmux-compose`

## Requirements

- bash 4.0+
- tmux 2.0+
- docker-compose 1.25+
- jq (for JSON config processing)
- yq (for YAML docker-compose parsing)

## How It Works

1. **Parse docker-compose.yml** to identify services
2. **Start containers** using `docker-compose up -d`
3. **Create tmux session** with organized layout
4. **Tail logs** for each service in separate windows/panes
5. **Setup keybinds** for easy container shell access

## Troubleshooting

### Common Issues

**Container not found for service:**
- Ensure containers are running with `docker-compose ps`
- Check service name matches docker-compose.yml

**Shell keybind not working:**
- Verify tmux prefix key (default: Ctrl+B)
- Check keybind configuration in tmux-compose.json
- Note: Shell and restart keybinds currently only work in window mode, not pane mode

**Missing dependencies:**
- Run the installer again to check requirements
- See installation section for OS-specific commands

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with the examples
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Roadmap

- [ ] **Proper pane mode support** - Fix shell access and restart keybinds to work with individual services in pane mode
- [ ] **Log storage and replay functionality** - Save container logs to files and replay them later
- [ ] **Support for docker-compose profiles** - Use `--profile` flag to activate specific service groups
- [ ] **Advanced layout configurations** - Custom tmux layouts and window arrangements
- [ ] **Health check integration** - Visual indicators for container health status
- [ ] **Multi-project session management** - Handle multiple docker-compose projects in one session
