#!/bin/bash
set -euo pipefail
native_root="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-app}"
case "$mode" in
  app) scheme="JPFRNativeLab" ;;
  safari) scheme="JPFRSafariLab" ;;
  *) echo "Mode attendu : app ou safari" >&2; exit 2 ;;
esac
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Cette vérification exige macOS et Xcode ; elle ne peut pas compiler sur Windows." >&2
  exit 2
fi
command -v xcodegen >/dev/null || { echo "Installer XcodeGen sur le Mac avant compilation." >&2; exit 2; }
sdk_version="$(xcrun --sdk iphoneos --show-sdk-version)"
python3 - "$sdk_version" <<'PY'
import sys
parts = tuple(int(x) for x in sys.argv[1].split(".")[:2])
if parts < (26, 4):
    raise SystemExit("Le prototype nécessite un SDK iOS 26.4 ou plus récent.")
PY
node "$native_root/Scripts/check-bridge.mjs"
if [ "$mode" = "app" ]; then
  swift test --package-path "$native_root" --scratch-path "$native_root/build/swift-contract"
fi
(cd "$native_root" && xcodegen generate --spec project.yml)
mkdir -p "$native_root/build/artifacts"
log="$native_root/build/artifacts/build-$mode.log"
if ! xcodebuild -project "$native_root/JPFRNative.xcodeproj" \
  -scheme "$scheme" -configuration Debug -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath "$native_root/build/$mode" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build >"$log" 2>&1; then
  tail -100 "$log"
  exit 1
fi
python3 "$native_root/Scripts/package-unsigned.py" "$mode" "$sdk_version"
echo "Compilation sans signature terminée. L'IPA ne s'installe pas telle quelle."
