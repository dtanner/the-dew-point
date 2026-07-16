# The Dew Point — development & deployment commands.
# Run `just` to list available recipes.

set shell := ["zsh", "-cu"]

# The paired Apple Watch's CoreDevice identifier (from `xcrun devicectl list
# devices`), used by devicectl to install/launch. Override: `just deploy watch=<uuid>`.
watch := "D0015F3B-57F5-58A2-B168-4577D3A78839"
# The same watch's xcodebuild destination id (from `xcodebuild -showdestinations`).
# Building against the specific device (not generic) is what registers the watch's
# UDID into the provisioning profile so it can be installed.
watch_build_id := "00008301-C89EE5061180202E"

# App Store Connect API key for `just release`. The key ID matches the
# AuthKey_<id>.p8 file in ~/.appstoreconnect/private_keys/; the issuer ID is
# shown at App Store Connect → Users & Access → Integrations. Neither is secret.
asc_key_id    := "22G36YCBG2"
asc_issuer_id := "b3f91fba-032a-4b10-b703-41d2ff812b78"

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
# Seeds the git-ignored secrets file first so a fresh clone builds; paste your
# AirNow API key into Config/Secrets.xcconfig to turn on the AQI complication.
generate:
    @[ -f Config/Secrets.xcconfig ] || cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
    xcodegen generate

# Render the word complication to a PNG for the README (macOS only).
complications:
    swift Scripts/render-complications.swift

# Render the app icon into the asset catalog (macOS only).
appicon:
    swift Scripts/render-appicon.swift

# The watchOS simulator to use for `just run-sim` (from `xcrun simctl list devices`).
# Override: `just run-sim sim="Apple Watch Ultra 3 (49mm)"`.
sim := "Apple Watch Series 11 (46mm)"

# Compile the watch app for the simulator (no device or paired watch needed).
build-app: generate
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPoint \
        -destination 'generic/platform=watchOS Simulator' \
        -quiet

# Build, install, and launch the watch app in the simulator.
run-sim: generate
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPoint \
        -destination 'platform=watchOS Simulator,name={{sim}}' \
        -derivedDataPath build/dd-sim \
        -quiet
    open -a Simulator
    xcrun simctl boot '{{sim}}' 2>/dev/null || true
    xcrun simctl install '{{sim}}' \
        build/dd-sim/Build/Products/Debug-watchsimulator/TheDewPoint.app
    xcrun simctl launch '{{sim}}' com.dantanner.dewpoint.watchkitapp

# Run in the simulator with fixed fake conditions instead of WeatherKit (which
# doesn't work in simulators). E.g. `just run-sim-fake 70 50` shows "Comfortable";
# `just run-sim-fake 70 60 "Heavy Rain"` forces a precipitation word, and a fourth
# argument fakes the AQI (`just run-sim-fake 70 50 "" 42`). The fakes also seed
# the shared caches, so complications placed on the sim's watch face show the
# same values once the app's launch reloads the timelines.
run-sim-fake temp dew precip="" aqi="": run-sim
    #!/usr/bin/env zsh
    set -eu
    fake="{{temp}},{{dew}}"
    [[ -n "{{precip}}" ]] && fake+=",{{precip}}"
    export SIMCTL_CHILD_DEWPOINT_FAKE="$fake"
    [[ -n "{{aqi}}" ]] && export SIMCTL_CHILD_DEWPOINT_FAKE_AQI="{{aqi}}"
    xcrun simctl launch --terminate-running-processes \
        '{{sim}}' com.dantanner.dewpoint.watchkitapp

# Build, sign, install, and launch on the paired Apple Watch.
# The watch must be unlocked, on the same Wi-Fi as this Mac, with Developer Mode
# on (keeping it on its charger helps it stay awake during install). The
# complication extension is embedded in the app, so it ships with this deploy;
# add the complications by editing a watch face on the watch or in the Watch app.
deploy: generate
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPoint \
        -destination 'platform=watchOS,id={{watch_build_id}}' \
        -allowProvisioningUpdates \
        -derivedDataPath build/dd \
        -quiet
    xcrun devicectl device install app --device {{watch}} \
        build/dd/Build/Products/Debug-watchos/TheDewPoint.app
    xcrun devicectl device process launch --device {{watch}} \
        com.dantanner.dewpoint.watchkitapp

# Bump the version, archive, and upload to TestFlight/App Store Connect, then commit and tag
release kind: test
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{kind}}" in major|minor|bugfix) ;; *)
        echo "usage: just release <major|minor|bugfix>"; exit 1 ;;
    esac
    key_path="$HOME/.appstoreconnect/private_keys/AuthKey_{{asc_key_id}}.p8"
    if [ ! -f "$key_path" ]; then
        echo "API key not found at $key_path"; exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "Working tree is dirty — commit or stash before releasing."; exit 1
    fi
    version=$(python3 - {{kind}} <<'EOF'
    import re, sys
    kind = sys.argv[1]
    yml = open("project.yml").read()
    major, minor, patch = (int(x) for x in re.search(r'MARKETING_VERSION: "([\d.]+)"', yml).group(1).split("."))
    if kind == "major": major, minor, patch = major + 1, 0, 0
    elif kind == "minor": minor, patch = minor + 1, 0
    else: patch += 1
    version = f"{major}.{minor}.{patch}"
    build = int(re.search(r'CURRENT_PROJECT_VERSION: "(\d+)"', yml).group(1)) + 1
    yml = re.sub(r'MARKETING_VERSION: "[\d.]+"', f'MARKETING_VERSION: "{version}"', yml)
    yml = re.sub(r'CURRENT_PROJECT_VERSION: "\d+"', f'CURRENT_PROJECT_VERSION: "{build}"', yml)
    open("project.yml", "w").write(yml)
    print(version)
    EOF
    )
    echo "Releasing $version"
    xcodegen generate
    # Archives the stub iOS container (which embeds the watch app) — see the
    # TheDewPointContainer comment in project.yml for why.
    xcodebuild -project TheDewPoint.xcodeproj -scheme TheDewPointContainer \
        -destination "generic/platform=iOS" \
        -archivePath build/release/TheDewPoint.xcarchive \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$key_path" \
        -authenticationKeyID {{asc_key_id}} \
        -authenticationKeyIssuerID {{asc_issuer_id}} \
        archive
    xcodebuild -exportArchive \
        -archivePath build/release/TheDewPoint.xcarchive \
        -exportOptionsPlist ExportOptions.plist \
        -exportPath build/release/export \
        -allowProvisioningUpdates \
        -authenticationKeyPath "$key_path" \
        -authenticationKeyID {{asc_key_id}} \
        -authenticationKeyIssuerID {{asc_issuer_id}}
    git commit -am "Release $version"
    git tag "v$version"
    git push origin HEAD "v$version"
    echo "Uploaded $version to App Store Connect; committed, tagged, and pushed v$version."
