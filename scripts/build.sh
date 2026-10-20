#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/bin"
DIST_DIR="${PROJECT_DIR}/dist"
JAR_NAME="io.github.dbeaver.export.geojson_1.0.0.jar"

echo "=========================================="
echo "    DBeaver GeoJSON Exporter Builder      "
echo "=========================================="

# Auto-detect DBeaver plugins installation path (Linux & macOS)
CANDIDATE_DIRS=(
  "$DBEAVER_HOME/plugins"
  "/usr/share/dbeaver-ce/plugins"
  "/usr/share/dbeaver/plugins"
  "/opt/dbeaver/plugins"
  "/Applications/DBeaver.app/Contents/Eclipse/plugins"
  "/Applications/DBeaverCE.app/Contents/Eclipse/plugins"
  "$HOME/Applications/DBeaver.app/Contents/Eclipse/plugins"
  "${PROJECT_DIR}/.dbeaver-lib/plugins"
)

DBEAVER_PLUGINS_DIR=""
for dir in "${CANDIDATE_DIRS[@]}"; do
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    DBEAVER_PLUGINS_DIR="$dir"
    break
  fi
done

if [ -z "$DBEAVER_PLUGINS_DIR" ]; then
  echo "Error: DBeaver plugins directory not found."
  echo "Please set DBEAVER_HOME to your DBeaver installation path."
  echo "Example: export DBEAVER_HOME=/usr/share/dbeaver-ce"
  exit 1
fi

echo "-> Using DBeaver libraries from: $DBEAVER_PLUGINS_DIR"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Assemble dynamic classpath
CP=$(find "$DBEAVER_PLUGINS_DIR" -name "*.jar" | tr '\n' ':')

echo "-> Compiling Java sources..."
javac -cp "$CP" -d "$BUILD_DIR" \
    "$PROJECT_DIR"/src/io/github/dbeaver/export/geojson/GeoJsonDataExporter.java

echo "-> Packaging OSGi bundle JAR..."
jar cfm "${DIST_DIR}/${JAR_NAME}" \
    "${PROJECT_DIR}/META-INF/MANIFEST.MF" \
    -C "$BUILD_DIR" . \
    -C "${PROJECT_DIR}" plugin.xml \
    -C "${PROJECT_DIR}" icons

echo "=== Build Successful! ==="
echo "Artifact generated: ${DIST_DIR}/${JAR_NAME}"
echo ""
echo "To install on local DBeaver instance:"
echo "  sudo ./scripts/install.sh"
echo "Then close DBeaver and launch it once with: dbeaver -clean"
