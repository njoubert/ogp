# OGP - Network Protocol Prototype

A C++ project for experimenting with a novel network protocol design.

## Quick Start

### First Time Setup

Run the provisioning script to install all required dependencies:

```bash
./provision.sh
```

This script is idempotent and checks for:

- Bazel 7.0.0+
- C++17 compatible compiler
- Git

### Building


Build all targets:
```bash
bazel build //...
```

Build specific targets:
```bash
bazel build //src/client:client
bazel build //src/server:server
bazel build //src/protocol:protocol
```

### Running

Run the server:
```bash
bazel run //src/server:server
```

Run the client:
```bash
bazel run //src/client:client
```

## Dependency Management

### Installing Dependencies

Use `provision.sh` to install all project dependencies with specific versions:

```bash
./provision.sh
```

This script:

- Checks if dependencies are already installed
- Verifies version requirements
- Only installs missing or outdated dependencies
- Is safe to run multiple times (idempotent)

### Upgrading Dependencies


Use `upgrade.sh` to upgrade dependencies to their latest versions:

```bash
./upgrade.sh
```

This script:

- Upgrades dependencies one at a time
- Tests the build after each upgrade
- Automatically rolls back failed upgrades
- Updates `provision.sh` with new working versions

## Prerequisites


- [Bazel](https://bazel.build/) 7.0.0+ (build system)
- Clang with C++17 support (Apple Clang 10.0+ or LLVM Clang 5.0+)
- Git

## Development Guidelines

- Follow modern C++ practices (C++17 or later)
- Use Clang as the C++ compiler
- Keep protocol definitions separate from implementation
- Document all protocol design decisions in `/docs/plans`
- Use Bazel for all build operations

## Testing

Run all tests:
```bash
bazel test //...
```
