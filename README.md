# OGP

OGP is a reliable, trustworthy, low-latency and highly-inefficient multi-path network protocol.

OGP duplicates outgoing packets across all available links, and picks the first next packet on any incoming link.
Later versions of OGP provide a simple framing for messages up to 64KB in size, and fragments messages into MTU-sized packets.
Even later versions of OGP will provide configurable retries for packets, forward error correction, and a maximum time-to-live for messages.

OGP is:

- is as low latency as the fastest wireless link.
- is as robust as all the links considered together.
- ensures data integrity with per-message checksums.
- provides forward error correction to minimize the impact of packet loss.
- unordered in message delivery, avoiding head-of-line blocking
- semi-reliable with messages mostly making it.
- not efficient in its bandwidth use, relying on redundant and duplicate data.
- built on top of IP/UDP

## What is this for?

OGP is well suited to small command-and-control style messages over multiple independent wireless internet links.

In particular we need to support two styles of messages:
- No delivery guarantee needed. Just try to get it out until the next equivalent message is available. We don't need to get an acknowledgement.
- Absolutely must be guaranteed up to some timeout. Keep retrying it until we get an acknowledgement.

OGP is very poorly suited for large file downloads or media streams.

## Roadmap

v1 - provides only redundant packets with a message size == MTU. no guarantees of delivery.

v2 - message size larger than wire MTU size, up to 64KB. no delivery guarantees.

v3 - soft deliver guarantees through limited retries and max TTLs. no ordering guarantees. (warning, unbounded memory growth theoretically possible)

v4 - forward error correction encoding for messages.

## Development

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

## License

```text
    OGP is a reliable multipath network protocol.

    Copyright (C) 2025 Niels Joubert

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. See LICENSE, or,  <https://www.gnu.org/licenses/>.
```
