# The Dew Point — development & deployment commands.
# Run `just` to list available recipes.

set shell := ["zsh", "-cu"]

# The paired Apple Watch's CoreDevice identifier (from `xcrun devicectl list
# devices`). Override per machine: `just deploy watch=<uuid>`.
watch := "D0015F3B-57F5-58A2-B168-4577D3A78839"

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

# Build, sign, install, and launch on the paired Apple Watch.
# The watch must be unlocked, on the same Wi-Fi as this Mac, with Developer Mode
# on (keeping it on its charger helps it stay awake during install).
deploy: generate
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPoint \
        -destination 'generic/platform=watchOS' \
        -allowProvisioningUpdates \
        -derivedDataPath build/dd \
        -quiet
    xcrun devicectl device install app --device {{watch}} \
        build/dd/Build/Products/Debug-watchos/TheDewPoint.app
    xcrun devicectl device process launch --device {{watch}} \
        com.dantanner.thedewpoint
