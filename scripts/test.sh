#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/bin/test"

CANDIDATE_DIRS=(
  "${DBEAVER_HOME:-}/plugins"
  "/usr/share/dbeaver-ce/plugins"
  "/usr/share/dbeaver/plugins"
  "/opt/dbeaver/plugins"
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
  echo "Error: DBeaver plugins directory not found." >&2
  echo "Set DBEAVER_HOME to the DBeaver installation path." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
CP=$(find "$DBEAVER_PLUGINS_DIR" -name "*.jar" -print0 | tr '\0' ':')

echo "-> Compiling tests using DBeaver libraries from: $DBEAVER_PLUGINS_DIR"
javac --release 17 -cp "$CP" -d "$BUILD_DIR" \
  "$PROJECT_DIR/src/io/github/dbeaver/export/geojson/GeoJsonDataExporter.java" \
  "$PROJECT_DIR/tests/io/github/dbeaver/export/geojson/GeoJsonDataExporterTest.java"

echo "-> Running GeoJSON exporter tests..."
java -cp "$BUILD_DIR:$CP" io.github.dbeaver.export.geojson.GeoJsonDataExporterTest
