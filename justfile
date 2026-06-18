# The Dew Point — development & deployment commands.
# Run `just` to list available recipes.

set shell := ["zsh", "-cu"]

# List available recipes.
default:
    @just --list

# Run the engine test suite (pure Swift, no Xcode/simulator needed).
test:
    swift test

# Build the engine package.
build:
    swift build

# Engine-only commands above. App/complication targets (XcodeGen project,
# device deploy) get added in M2/M3.
