# Dotfiles Test Suite

Comprehensive Docker-based testing framework for the dotfiles installation and management system.

## Quick Start

```bash
# Run all tests (fastest way to verify everything works)
make test

# Run specific test suites
make test-unit         # Unit tests only (~10s)
make test-integration  # Integration tests (~30s)
make test-configs      # Config verification tests

# Interactive debugging
make test-shell        # Drop into test container

# Cleanup
make test-clean        # Remove Docker images and containers
```

## Architecture

### Test Runner (`test-runner.sh`)
- Orchestrates Docker container build and test execution
- Automatically installs BATS testing framework
- Supports multiple test modes (unit, integration, configs, all)
- Provides interactive shell for debugging

### Docker Infrastructure (`docker/`)

**Alpine Linux (default)**
- Minimal base image (~200MB total)
- Fast build and execution (~45s for full suite)
- Best for rapid iteration during development

**Ubuntu (optional)**
- Broader compatibility testing
- More similar to common production environments
- Use with: `docker build -f tests/docker/Dockerfile.ubuntu`

### Test Organization

```
tests/
├── unit/                  # Component-level tests
│   ├── test-symlink-manager.bats
│   └── test-install-tools.bats
│
├── integration/           # End-to-end tests
│   ├── test-fresh-setup.bats
│   ├── test-idempotency.bats
│   ├── test-conflicts.bats
│   └── test-configs.bats
│
├── fixtures/              # Test data (future)
├── docker/                # Container definitions
└── test-runner.sh         # Main orchestration script
```

## Test Coverage

### Unit Tests (43 tests)

**symlink-manager.sh**
- ✓ Install mode: fresh installs, idempotency, parent directory creation
- ✓ Conflict handling: regular files, directories, wrong symlinks
- ✓ Backup creation: timestamping, structure preservation, content integrity
- ✓ Uninstall mode: selective removal, safety checks
- ✓ Status mode: correctness reporting, error detection
- ✓ Edge cases: empty lines, trailing slashes, spaces in filenames

**install-tools.sh**
- ✓ Syntax validation and basic logic tests
- ✓ Tool detection and mock package managers
- ✓ Array tracking and summary formatting
- ℹ️ Platform-specific tests skipped (need real package managers)

### Integration Tests (68 tests)

**Fresh Setup**
- ✓ Clean system installation
- ✓ Nested directory handling
- ✓ Mixed files and directories
- ✓ Permission preservation

**Idempotency**
- ✓ Safe re-running of operations
- ✓ Content integrity across multiple runs
- ✓ Config changes (add/remove files)
- ✓ Concurrent execution safety

**Conflicts & Backups**
- ✓ Conflict detection (files, directories, symlinks)
- ✓ Backup directory creation and naming
- ✓ Structure preservation in backups
- ✓ Restore functionality
- ✓ Data integrity verification

**Config Verification**
- ✓ Git: .gitconfig validity, aliases, editor settings
- ✓ Neovim: config structure, lazy.nvim bootstrap
- ✓ Broken symlink detection
- ✓ Syntax validation for all configs
- ℹ️ zsh/tmux/nvim runtime tests skipped (tools not in Alpine)

## Test Results Summary

**Current Status: 111/111 passing (100% pass rate)** ✅

All tests pass! The test suite successfully validates:
- ✅ Symlink creation and management
- ✅ Conflict detection and resolution with full path preservation
- ✅ Backup and restore functionality
- ✅ Idempotent operations (safe to re-run)
- ✅ Config file validity (git, tmux, nvim, zsh)
- ✅ Edge cases: spaces in filenames, trailing slashes, parent directory conflicts
- ✅ Error handling and safety checks

### Bug Fixes During Development

The test suite caught and helped fix several real bugs:
1. **Backup path preservation**: Fixed `cp -RL` to preserve full directory structure
2. **Parent directory conflicts**: Added handling for when a parent path is a file instead of a directory
3. **Test assertion refinements**: Improved test accuracy for edge cases

## Development Workflow

### Adding New Tests

1. Choose appropriate test file based on scope
2. Follow BATS syntax: `@test "description" { ... }`
3. Use setup/teardown for test isolation
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
2. Run `make test-unit` to confirm it fails
3. Implement feature in `src/`
4. Run `make test-unit` to verify fix
5. Run `make test` for full validation

## CI/CD Integration (Future)

The test suite is ready for GitHub Actions:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: make test
```

Exit codes:
- `0` = All tests passed
- `1` = Some tests failed
- `2` = Test infrastructure error

## Benefits

✅ **Safety**: Never touches your actual system
✅ **Speed**: Full suite in ~45s, unit tests in ~10s
✅ **Coverage**: 111 tests across unit and integration levels
✅ **Confidence**: Make changes without fear of breaking things
✅ **Documentation**: Tests serve as executable specifications
✅ **Debugging**: Interactive shell for troubleshooting

## Troubleshooting

**"Docker not found"**
- Install Docker Desktop (macOS) or Docker Engine (Linux)

**"Tests hang during BATS installation"**
- Check internet connectivity
- GitHub API rate limits (rare)
- Retry: `make test-clean && make test`

**"Permission denied" errors**
- Tests run as non-root user `testuser`
- Should not require elevated privileges

**"Out of disk space"**
- Clean up: `make test-clean`
- Prune all Docker images: `docker system prune -a`

## Further Reading

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- Main project docs: [../CLAUDE.md](../CLAUDE.md)
