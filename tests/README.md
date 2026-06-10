# Dotfiles Test Suite

Docker-based testing framework for the dotfiles installation and management system.

## Quick Start

```bash
# Fast local validation without Docker
make doctor
make shellcheck

# Run all tests (fastest way to verify everything works)
make test

# Interactive debugging
make test-shell        # Drop into test container

# Cleanup
make test-clean        # Remove Docker images and containers
```

## Architecture

### Test Runner (`test-runner.sh`)

- Orchestrates Docker container build and test execution
- Supports all tests or a single `.bats` file
- Provides interactive shell for debugging
- BATS is baked into the test image; the runner only downloads it as a
  fallback when run outside the container

### Docker Infrastructure (`docker/`)

**`Dockerfile.alpine`** — the test image

- Alpine base with zsh, tmux, and neovim installed so the config
  integration tests actually run instead of skipping
- BATS pre-installed (no network dependency per test run)

**`Dockerfile.dev`** — interactive Ubuntu environment for `make dev-shell`

- Runs the real `install-tools.sh` + `symlink-manager.sh` install
- Use it to try the dotfiles end-to-end in a throwaway box

### Test Organization

```
tests/
├── unit/                  # One test file per script (test-<name>.bats)
├── integration/           # End-to-end: fresh setup, idempotency,
│                          # conflicts/backup/restore, config validity
├── docker/                # Container definitions
└── test-runner.sh         # Main orchestration script
```

Unit tests cover each custom script and the symlink manager; integration
tests install the real dotfiles into an isolated `$HOME` and verify
behavior (including restore and the zsh/tmux/nvim configs).

## Development Workflow

### Adding New Tests

1. Choose the appropriate test file based on scope
2. Follow BATS syntax: `@test "description" { ... }`
3. Use setup/teardown for test isolation (`mktemp -d` + `HOME` override)
4. Test both success and failure paths

**Example:**

```bash
@test "my new feature: does the thing" {
    # Setup
    echo "test data" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.testfile" ]
}
```

### Debugging Failed Tests

```bash
# Run specific test file
make test-shell
cd /home/testuser/dotfiles
bats tests/unit/test-symlink-manager.bats

# Run single test by line number
bats tests/unit/test-symlink-manager.bats:175

# Verbose output
bats -t tests/unit/test-symlink-manager.bats
```

### Test-Driven Development

1. Write failing test for new feature
2. Run `make test` to confirm it fails
3. Implement feature in `src/`
4. Run `make test` to verify fix

## CI/CD Integration

GitHub Actions runs `make doctor`, `make shellcheck`, and `make test` on
pushes to `master` and on pull requests — see
[`.github/workflows/test.yml`](../.github/workflows/test.yml).

Exit codes: `0` = all tests passed, non-zero = failures.

## Benefits

✅ **Safety**: Never touches your actual system
✅ **Confidence**: Make changes without fear of breaking things
✅ **Documentation**: Tests serve as executable specifications
✅ **Debugging**: Interactive shell for troubleshooting

## Troubleshooting

**"Docker not found"**

- Install Docker Desktop (macOS) or Docker Engine (Linux)

**"Permission denied" errors**

- Tests run as non-root user `testuser`
- Should not require elevated privileges

**"Out of disk space"**

- Clean up: `make test-clean`
- Prune all Docker images: `docker system prune -a`

## Further Reading

- [BATS Documentation](https://bats-core.readthedocs.io/)
- Main project docs: [../CLAUDE.md](../CLAUDE.md)
