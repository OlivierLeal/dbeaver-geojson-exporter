#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAR_FILE="${PROJECT_DIR}/dist/io.github.dbeaver.export.geojson_1.0.1.jar"

# Auto-detect DBeaver installation directory (Linux & macOS)
CANDIDATE_DIRS=(
  "$DBEAVER_HOME"
  "/usr/share/dbeaver-ce"
  "/usr/share/dbeaver"
  "/opt/dbeaver"
  "/Applications/DBeaver.app/Contents/Eclipse"
  "/Applications/DBeaverCE.app/Contents/Eclipse"
  "$HOME/Applications/DBeaver.app/Contents/Eclipse"
)

DBEAVER_DIR=""
for dir in "${CANDIDATE_DIRS[@]}"; do
  if [ -n "$dir" ] && [ -d "$dir/plugins" ]; then
    DBEAVER_DIR="$dir"
    break
  fi
done

if [ -z "$DBEAVER_DIR" ]; then
  echo "Error: DBeaver installation directory not found."
  echo "Please set DBEAVER_HOME to your DBeaver installation path."
  exit 1
fi

BUNDLES_INFO="${DBEAVER_DIR}/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
PLUGIN_TARGET="${DBEAVER_DIR}/plugins/io.github.dbeaver.export.geojson_1.0.1.jar"
BUNDLE_ENTRY="io.github.dbeaver.export.geojson,1.0.1,plugins/io.github.dbeaver.export.geojson_1.0.1.jar,4,false"

if [ "$EUID" -ne 0 ]; then
  echo "Error: Root privileges required."
  echo "Please run with sudo:"
  echo "  sudo ./scripts/install.sh"
  exit 1
fi

if [ ! -f "$JAR_FILE" ]; then
  echo "Error: Built JAR not found at $JAR_FILE."
  echo "Please run ./scripts/build.sh first."
  exit 1
fi

echo "-> Installing plugin JAR to ${PLUGIN_TARGET}..."
cp "$JAR_FILE" "$PLUGIN_TARGET"
rm -f "${DBEAVER_DIR}/plugins/io.github.dbeaver.export.geojson_1.0.0.jar"

# Remove legacy dropins copy if present
rm -f "${DBEAVER_DIR}/dropins/io.github.dbeaver.export.geojson_1.0.0.jar" "${DBEAVER_DIR}/dropins/io.github.dbeaver.export.geojson_1.0.1.jar" 2>/dev/null || true

# Register the exact bundle entry used by this release. Replacing an existing
# entry avoids retaining a stale path after a DBeaver or plugin update.
if [ ! -f "$BUNDLES_INFO" ]; then
  echo "Error: Equinox configuration file not found: $BUNDLES_INFO"
  exit 1
fi

echo "-> Registering bundle in Equinox simpleconfigurator..."
cp "$BUNDLES_INFO" "${BUNDLES_INFO}.bak"
sed -i '/^io\.github\.dbeaver\.export\.geojson,/d' "$BUNDLES_INFO"
echo "$BUNDLE_ENTRY" >> "$BUNDLES_INFO"

echo "=== Installation Completed Successfully! ==="
echo "Close every DBeaver window, then start it once with:"
echo "  dbeaver -clean"
echo "The -clean flag refreshes DBeaver's plugin registry."
