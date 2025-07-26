# Contributing to tmux-compose

Thank you for your interest in contributing to tmux-compose! We welcome contributions from the community.

## How to Contribute

### Reporting Issues

Before creating an issue, please:
- Check if the issue already exists in the [GitHub Issues](../../issues)
- Include your system information (OS, tmux version, docker-compose version)
- Provide a minimal example to reproduce the problem
- Include relevant logs (use `--debug` flag for verbose output)

### Suggesting Features

When suggesting new features:
- Check the [Roadmap](README.md#roadmap) to see if it's already planned
- Open an issue with the "enhancement" label
- Describe the use case and expected behavior
- Consider backwards compatibility

### Development Setup

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/yourusername/tmux-compose.git
   cd tmux-compose
   ```

2. **Install dependencies**
   ```bash
   # See README.md for OS-specific installation commands
   sudo pacman -S tmux docker-compose jq yq  # Arch example
   ```

3. **Test your setup**
   ```bash
   cd examples/
   ../tmux-compose up
   ```

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow the code style**
   - Use 4 spaces for indentation
   - Add comments for complex logic
   - Use descriptive function and variable names
   - Follow existing patterns in the codebase

3. **Test your changes**
   - Test with the provided examples
   - Test on different docker-compose configurations
   - Verify backwards compatibility
   - Test the installation script

4. **Update documentation**
   - Update README.md if adding new features
   - Add examples for new configuration options
   - Update help text if changing commands

### Code Guidelines

#### Shell Scripting Best Practices
- Use `set -euo pipefail` for error handling
- Quote variables: `"$variable"` instead of `$variable`
- Use `local` for function variables
- Prefer `[[ ]]` over `[ ]` for conditionals
- Use `mapfile` instead of command substitution loops

#### Function Structure
```bash
# Brief description of what the function does
function_name() {
    local param1="$1"
    local param2="${2:-default_value}"
    
    # Function logic here
    log "Descriptive message"
    debug "Debug information"
}
```

#### Error Handling
- Use `error "message"` for fatal errors
- Use `warn "message"` for warnings
- Use `log "message"` for normal output
- Use `debug "message"` for debug information

### Testing

Before submitting:
- [ ] Test with multiple docker-compose projects
- [ ] Test both window and pane modes
- [ ] Test shell access functionality
- [ ] Test installation script on clean system
- [ ] Verify no regressions in existing functionality

### Submitting Changes

1. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

2. **Use conventional commits**
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation changes
   - `refactor:` for code refactoring
   - `test:` for test additions

3. **Push and create pull request**
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Pull request guidelines**
   - Provide clear description of changes
   - Reference related issues
   - Include testing steps
   - Update CHANGELOG if significant change

## Project Structure

```
tmux-compose/
├── tmux-compose          # Main executable script
├── lib/                  # Library modules
│   ├── config.sh        # Configuration management
│   ├── docker.sh        # Docker-compose integration
│   ├── tmux.sh          # Tmux session management
│   └── utils.sh         # Utility functions
├── examples/            # Example configurations
├── install.sh          # Installation script
└── README.md           # Documentation
```

## Getting Help

- Read the [README.md](README.md) documentation
- Check existing [issues](../../issues) and [discussions](../../discussions)
- Ask questions in GitHub Discussions
- Join our community discussions

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and contribute
- Follow GitHub's Community Guidelines

Thank you for contributing to tmux-compose! 🚀
