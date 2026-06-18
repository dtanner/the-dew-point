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

# Regenerate the Xcode project from project.yml (run after cloning or editing it).
generate:
    xcodegen generate

# Compile the watch app for the simulator (no device or paired watch needed).
build-app: generate
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPoint \
        -destination 'generic/platform=watchOS Simulator' \
        -quiet
