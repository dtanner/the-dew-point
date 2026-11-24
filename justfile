# The Dew Point — development & deployment commands.
# Run `just` to list available recipes.

set shell := ["zsh", "-cu"]

# The paired Apple Watch for `just deploy`. Empty auto-discovers it; override
# with `WATCH=<name-or-udid> just deploy`.
watch := env_var_or_default("WATCH", "")
bundle_id := "com.dantanner.dewpoint.watchkitapp"

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
[doc("Regenerate the Xcode project from project.yml (seeds Config/Secrets.xcconfig on first run).")]
generate:
    @[ -f Config/Secrets.xcconfig ] || cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
    xcodegen generate

# Render the word complication to a PNG for the README (macOS only).
complications:
    swift Scripts/render-complications.swift

# Render the app icon into the watch and iPhone asset catalogs (macOS only).
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
    # DeviceHub (Xcode 27+) is the app that shows simulators.
    open -b com.apple.dt.Devices
    xcrun simctl boot '{{sim}}' 2>/dev/null || true
    xcrun simctl install '{{sim}}' \
        build/dd-sim/Build/Products/Debug-watchsimulator/TheDewPoint.app
    xcrun simctl launch '{{sim}}' {{bundle_id}}

# Run in the simulator with fixed fake conditions instead of WeatherKit (which
# doesn't work in simulators). E.g. `just run-sim-fake 70 50` shows "Comfortable";
# `just run-sim-fake 70 60 "Heavy Rain"` forces a precipitation word, and a fourth
# argument fakes the AQI (`just run-sim-fake 70 50 "" 42`). The fakes also seed
# the shared caches, so complications placed on the sim's watch face show the
# same values once the app's launch reloads the timelines.
[doc('Run in the simulator with fake conditions, e.g. `just run-sim-fake 70 50 "Heavy Rain" 42`.')]
run-sim-fake temp dew precip="" aqi="": run-sim
    #!/usr/bin/env zsh
    set -eu
    fake="{{temp}},{{dew}}"
    [[ -n "{{precip}}" ]] && fake+=",{{precip}}"
    export SIMCTL_CHILD_DEWPOINT_FAKE="$fake"
    [[ -n "{{aqi}}" ]] && export SIMCTL_CHILD_DEWPOINT_FAKE_AQI="{{aqi}}"
    xcrun simctl launch --terminate-running-processes \
        '{{sim}}' {{bundle_id}}

# The iPhone simulator for `just run-phone-sim`.
# Override: `just run-phone-sim phone_sim="iPhone 17e"`.
phone_sim := "iPhone 17 Pro"
phone_bundle_id := "com.dantanner.dewpoint"

# Compile the iPhone app (which embeds the watch app) for the simulator.
build-phone: generate
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPointPhone \
        -destination 'generic/platform=iOS Simulator' \
        -quiet

# Build, install, and launch the iPhone app in the simulator. Pass fake conditions
# the same way as `run-sim-fake`, e.g. `just run-phone-sim 70 64 "" 42`, since
# WeatherKit doesn't work in simulators.
[doc('Run the iPhone app in the simulator, optionally with fake conditions: `just run-phone-sim 70 64 "Heavy Rain" 42`.')]
run-phone-sim temp="" dew="" precip="" aqi="" device=phone_sim: generate
    #!/usr/bin/env zsh
    set -eu
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPointPhone \
        -destination 'platform=iOS Simulator,name={{device}}' \
        -derivedDataPath build/dd-phone-sim \
        -quiet
    open -b com.apple.dt.Devices
    xcrun simctl boot '{{device}}' 2>/dev/null || true
    xcrun simctl install '{{device}}' \
        build/dd-phone-sim/Build/Products/Debug-iphonesimulator/TheDewPoint.app
    if [[ -n "{{temp}}" && -n "{{dew}}" ]]; then
        fake="{{temp}},{{dew}}"
        [[ -n "{{precip}}" ]] && fake+=",{{precip}}"
        export SIMCTL_CHILD_DEWPOINT_FAKE="$fake"
    fi
    [[ -n "{{aqi}}" ]] && export SIMCTL_CHILD_DEWPOINT_FAKE_AQI="{{aqi}}"
    xcrun simctl launch --terminate-running-processes '{{device}}' {{phone_bundle_id}}

# App Store screenshots of each iPhone tab, on the 6.9" simulator App Store
# Connect requires, with fake conditions and a clean status bar. Writes
# build/screenshots/phone/<tab>.png. E.g. `just phone-screenshots 70 64 "" 38`.
[doc('Screenshot each iPhone tab on the 6.9" simulator: `just phone-screenshots 70 64 "" 38`.')]
phone-screenshots temp="70" dew="64" precip="" aqi="38" device="iPhone 17 Pro Max": (run-phone-sim temp dew precip aqi device)
    #!/usr/bin/env zsh
    set -eu
    out=build/screenshots/phone
    mkdir -p "$out"
    xcrun simctl status_bar '{{device}}' override --time 9:41 --batteryState charged \
        --batteryLevel 100 --cellularBars 4 --wifiBars 3
    fake="{{temp}},{{dew}}"
    [[ -n "{{precip}}" ]] && fake+=",{{precip}}"
    export SIMCTL_CHILD_DEWPOINT_FAKE="$fake"
    [[ -n "{{aqi}}" ]] && export SIMCTL_CHILD_DEWPOINT_FAKE_AQI="{{aqi}}"
    for tab in now today bands words; do
        SIMCTL_CHILD_DEWPOINT_TAB=$tab xcrun simctl launch --terminate-running-processes \
            '{{device}}' {{phone_bundle_id}} >/dev/null
        sleep 3
        xcrun simctl io '{{device}}' screenshot "$out/$tab.png" >/dev/null
        echo "$out/$tab.png"
    done
    xcrun simctl status_bar '{{device}}' clear

# Stream the watch app's logs from the simulator.
logs:
    xcrun simctl spawn '{{sim}}' log stream --level debug \
        --predicate 'subsystem CONTAINS "com.dantanner.dewpoint"'

# Screenshot the watch simulator into images/screenshots/<name>.png.
shot name:
    @mkdir -p images/screenshots
    xcrun simctl io '{{sim}}' screenshot images/screenshots/{{name}}.png

# List connected physical devices and their UDIDs.
devices:
    xcrun devicectl list devices

# Build, sign, install, and launch on the paired Apple Watch.
# The watch must be unlocked, on the same Wi-Fi as this Mac, with Developer Mode
# on (keeping it on its charger helps it stay awake during install). The
# complication extension is embedded in the app, so it ships with this deploy;
# add the complications by editing a watch face on the watch or in the Watch app.
[doc("Build, sign, install, and launch on the paired Apple Watch (auto-discovers it; or `WATCH=<name-or-udid> just deploy`).")]
deploy: generate
    #!/usr/bin/env zsh
    set -eu
    dev="{{watch}}"
    if [[ -z "$dev" ]]; then
        json=$(mktemp)
        xcrun devicectl list devices --json-output "$json" >/dev/null
        # First physical, paired Apple Watch. devicectl also lists simulators
        # (reality "simulated"). Its hardware UDID works both as the xcodebuild
        # destination id and as devicectl's --device.
        dev=$(python3 -c "import json; ds=json.load(open('$json'))['result']['devices']; ok=lambda d: d.get('hardwareProperties',{}).get('productType','').startswith('Watch') and d.get('hardwareProperties',{}).get('reality')!='simulated' and d.get('connectionProperties',{}).get('pairingState')=='paired' and d.get('connectionProperties',{}).get('tunnelState')!='unavailable'; print(next((d['hardwareProperties']['udid'] for d in ds if ok(d)), ''))")
        rm -f "$json"
    fi
    if [[ -z "$dev" ]]; then
        echo "No paired Apple Watch reachable. Run 'just devices' to inspect, or WATCH=<name-or-udid> just deploy"
        exit 1
    fi
    # Building against the specific device (not generic) is what registers the
    # watch's UDID into the provisioning profile so it can be installed.
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPoint \
        -destination "platform=watchOS,id=$dev" \
        -allowProvisioningUpdates \
        -derivedDataPath build/dd \
        -quiet
    xcrun devicectl device install app --device "$dev" \
        build/dd/Build/Products/Debug-watchos/TheDewPoint.app
    xcrun devicectl device process launch --device "$dev" {{bundle_id}}

# The iPhone for `just deploy-phone`. Empty auto-discovers the first paired one;
# override with `PHONE=<name-or-udid> just deploy-phone`.
phone := env_var_or_default("PHONE", "")

# Build, sign, install, and launch the iPhone app (with its widgets) on a paired
# iPhone. The phone must be unlocked with Developer Mode on. The embedded watch app
# isn't pushed to the watch by this; use `just deploy` for the watch.
[doc("Build, sign, install, and launch on a paired iPhone (auto-discovers it; or `PHONE=<name-or-udid> just deploy-phone`).")]
deploy-phone: generate
    #!/usr/bin/env zsh
    set -eu
    dev="{{phone}}"
    if [[ -z "$dev" ]]; then
        json=$(mktemp)
        xcrun devicectl list devices --json-output "$json" >/dev/null
        # First physical, paired iPhone (devicectl also lists simulators).
        dev=$(python3 -c "import json; ds=json.load(open('$json'))['result']['devices']; ok=lambda d: d.get('hardwareProperties',{}).get('productType','').startswith('iPhone') and d.get('hardwareProperties',{}).get('reality')!='simulated' and d.get('connectionProperties',{}).get('pairingState')=='paired' and d.get('connectionProperties',{}).get('tunnelState')!='unavailable'; print(next((d['hardwareProperties']['udid'] for d in ds if ok(d)), ''))")
        rm -f "$json"
    fi
    if [[ -z "$dev" ]]; then
        echo "No paired iPhone reachable. Run 'just devices' to inspect, or PHONE=<name-or-udid> just deploy-phone"
        exit 1
    fi
    # Building for the specific device registers it (and any new App ID, such as
    # the widget extension's) through automatic provisioning.
    xcodebuild build \
        -project TheDewPoint.xcodeproj \
        -scheme TheDewPointPhone \
        -destination "platform=iOS,id=$dev" \
        -allowProvisioningUpdates \
        -derivedDataPath build/dd-phone \
        -quiet
    xcrun devicectl device install app --device "$dev" \
        build/dd-phone/Build/Products/Debug-iphoneos/TheDewPoint.app
    xcrun devicectl device process launch --device "$dev" {{phone_bundle_id}}

# Run SwiftLint (strict: warnings fail too)
lint:
    swiftlint lint --strict --quiet

# Run tests, lint, and build — the same checks the pre-commit hook runs
check: test lint build build-app build-phone

# Install a git pre-commit hook that runs `just check` before each commit
install-hooks:
    #!/usr/bin/env bash
    set -euo pipefail
    # --git-path resolves the hooks dir from a worktree too.
    hook="$(git rev-parse --git-path hooks)/pre-commit"
    mkdir -p "$(dirname "$hook")"
    printf '#!/bin/sh\nexec just check\n' > "$hook"
    chmod +x "$hook"
    echo "Installed pre-commit hook: $hook"

# Bump the version, archive, and upload to TestFlight/App Store Connect, then commit and tag
release kind: test lint
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{kind}}" in major|minor|bugfix) ;; *)
        echo "usage: just release <major|minor|bugfix>"; exit 1 ;;
    esac
    if [ -z "{{asc_issuer_id}}" ]; then
        echo "Missing App Store Connect issuer ID: set asc_issuer_id in the justfile"
        echo "or ASC_ISSUER_ID in the environment. It's shown at App Store Connect →"
        echo "Users & Access → Integrations → App Store Connect API."
        exit 1
    fi
    key_path="$HOME/.appstoreconnect/private_keys/AuthKey_{{asc_key_id}}.p8"
    if [ ! -f "$key_path" ]; then
        echo "API key not found at $key_path"; exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "Working tree is dirty — commit or stash before releasing."; exit 1
    fi
    # A release must be cut from an up-to-date main; anything else (an unmerged
    # branch, a stale checkout) would ship and tag code that main doesn't have.
    git fetch origin main --tags --quiet
    if ! git merge-base --is-ancestor origin/main HEAD; then
        echo "HEAD is not a fast-forward of origin/main; a release must be cut from main." >&2
        echo "  HEAD:        $(git rev-parse --short HEAD)" >&2
        echo "  origin/main: $(git rev-parse --short origin/main)" >&2
        exit 1
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
    # Archives the iPhone app, which embeds the watch app — see the
    # TheDewPointPhone comment in project.yml.
    xcodebuild -project TheDewPoint.xcodeproj -scheme TheDewPointPhone \
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

    # Release notes from the commits since the last release go in the tag's
    # annotation (read them with `git show v<version>`).
    prev_tag=$(git describe --tags --abbrev=0 --match 'v*' HEAD~1 2>/dev/null || echo "")
    if [ -n "$prev_tag" ]; then
        commit_log=$(git log "${prev_tag}..HEAD~1" --oneline --no-merges)
    else
        commit_log=$(git log HEAD~1 --oneline --no-merges -20)
    fi
    notes_file=$(mktemp)
    trap 'rm -f "$notes_file"' EXIT
    prompt="Generate concise release notes for version $version of The Dew Point (an Apple Watch and iPhone app showing how humid it feels).
    Here are the commits since ${prev_tag:-the beginning}:

    ${commit_log}

    Guidelines:
    - Group related commits into a single bullet point
    - Focus on user-facing changes, not implementation details
    - Skip version bumps, tooling changes, and purely internal refactors
    - Keep each bullet to one line, use past tense
    - Output only a bullet list (- item), nothing else"
    if command -v claude &>/dev/null && claude -p "$prompt" > "$notes_file" 2>/dev/null && [ -s "$notes_file" ]; then
        echo "Release notes (generated by Claude):"
    else
        echo "$commit_log" | sed 's/^[0-9a-f]* /- /' > "$notes_file"
        echo "Release notes (from commit log):"
    fi
    cat "$notes_file"

    git tag -a "v$version" -F "$notes_file"
    # Named refs rather than the branch's upstream, so this behaves the same
    # from the main checkout, a worktree, or any branch name.
    git push origin HEAD:main
    git push origin "refs/tags/v$version"
    echo "Uploaded $version to App Store Connect; committed, tagged, and pushed v$version."

# Open the project in Xcode.
open: generate
    open TheDewPoint.xcodeproj

# Remove build artifacts.
clean:
    rm -rf build .build
