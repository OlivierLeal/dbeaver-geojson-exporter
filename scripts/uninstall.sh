#!/usr/bin/env bash
set -e

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
  exit 1
fi

BUNDLES_INFO="${DBEAVER_DIR}/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
PLUGIN_TARGET="${DBEAVER_DIR}/plugins/io.github.dbeaver.export.geojson_1.0.1.jar"

if [ "$EUID" -ne 0 ]; then
  echo "Error: Root privileges required."
  echo "Please run with sudo:"
  echo "  sudo ./scripts/uninstall.sh"
  exit 1
fi

echo "=== Uninstalling DBeaver GeoJSON Exporter ==="

# Remove JAR file
if [ -f "$PLUGIN_TARGET" ]; then
  echo "-> Removing plugin JAR from ${PLUGIN_TARGET}..."
  rm -f "$PLUGIN_TARGET"
fi
rm -f "${DBEAVER_DIR}/plugins/io.github.dbeaver.export.geojson_1.0.0.jar"

# Remove legacy dropins copy
rm -f "${DBEAVER_DIR}/dropins/io.github.dbeaver.export.geojson_1.0.0.jar" "${DBEAVER_DIR}/dropins/io.github.dbeaver.export.geojson_1.0.1.jar" 2>/dev/null || true

# Remove entry from bundles.info
if [ -f "$BUNDLES_INFO" ] && grep -q "io.github.dbeaver.export.geojson" "$BUNDLES_INFO"; then
  echo "-> Removing bundle entry from Equinox bundles.info..."
  sed -i '/io\.github\.dbeaver\.export\.geojson/d' "$BUNDLES_INFO"
fi

echo "=== Plugin Uninstalled Successfully! ==="
echo "Restart DBeaver with: dbeaver -clean &"
