#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-build}"
APP_NAME="ClashFX"
SCHEME="ClashFX"
CONFIGURATION="${CONFIGURATION:-Debug}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-}"
KILL_RUNNING_APP="${KILL_RUNNING_APP:-0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$ROOT_DIR/ClashFX.xcworkspace"
DERIVED_DATA="$ROOT_DIR/build_derived_data"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BUNDLE_ID="com.clashfx.app"

candidate_pids() {
    local pid command
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
        if [[ "$command" == "$APP_BINARY"* ]]; then
            printf '%s\n' "$pid"
        fi
    done < <(pgrep -x "$APP_NAME" 2>/dev/null || true)
}

refuse_parallel_launch() {
    local pid command
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
        if [[ "$command" != "$APP_BINARY"* ]]; then
            echo "Refusing to launch the candidate while another ClashFX is running: $command" >&2
            echo "The installed app may be providing the active network proxy." >&2
            return 1
        fi
        echo "Refusing to launch a second migration candidate (PID $pid)." >&2
        return 1
    done < <(pgrep -x "$APP_NAME" 2>/dev/null || true)
}

if [[ "$KILL_RUNNING_APP" == "1" ]]; then
    while IFS= read -r pid; do
        kill "$pid"
    done < <(candidate_pids)
fi

if [[ ! -f "$WORKSPACE/contents.xcworkspacedata" ]]; then
    echo "ClashFX.xcworkspace is not bootstrapped. Run ./install_dependency.sh first." >&2
    exit 1
fi

build_args=(
    build
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -derivedDataPath "$DERIVED_DATA"
)

if [[ -n "$SOURCE_PACKAGES_DIR" ]]; then
    build_args+=(
        -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR"
        -disableAutomaticPackageResolution
        -onlyUsePackageVersionsFromResolvedFile
    )
fi

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
    build_args+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

if [[ -n "${CODE_SIGNING_ALLOWED:-}" ]]; then
    build_args+=("CODE_SIGNING_ALLOWED=$CODE_SIGNING_ALLOWED")
fi

xcodebuild "${build_args[@]}"

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "Built app was not found at $APP_BUNDLE" >&2
    exit 1
fi

if /usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP_BUNDLE/Contents/Info.plist" >/dev/null 2>&1; then
    echo "Fork build unexpectedly contains an upstream Sparkle feed URL." >&2
    exit 1
fi

if [[ ! -f "$APP_BUNDLE/Contents/Resources/MenuIcons/menu-fork-classic.png" ]]; then
    echo "Fork menu icon is missing from the built app." >&2
    exit 1
fi

open_app() {
    refuse_parallel_launch
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    --build|build)
        ;;
    run)
        open_app
        ;;
    --debug|debug)
        refuse_parallel_launch
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        open_app
        for _ in {1..20}; do
            if [[ -n "$(candidate_pids)" ]]; then
                exit 0
            fi
            sleep 0.25
        done
        echo "Migration candidate did not remain running." >&2
        exit 1
        ;;
    *)
        echo "usage: $0 [build|run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
