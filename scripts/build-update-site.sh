#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="${PROJECT_DIR}/site"

echo "=========================================="
echo "   Building Eclipse P2 Update Site        "
echo "=========================================="

# 1. Build the plugin jar first
"$PROJECT_DIR/scripts/build.sh"

# Locate DBeaver plugins directory and equinox launcher
CANDIDATE_DIRS=(
  "$DBEAVER_HOME/plugins"
  "/usr/share/dbeaver-ce/plugins"
  "/usr/share/dbeaver/plugins"
  "/opt/dbeaver/plugins"
  "/Applications/DBeaver.app/Contents/Eclipse/plugins"
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
  exit 1
fi

LAUNCHER=$(find "$DBEAVER_PLUGINS_DIR" -name "org.eclipse.equinox.launcher_*.jar" | head -n 1)
if [ -z "$LAUNCHER" ]; then
  echo "Error: Eclipse Equinox launcher not found in $DBEAVER_PLUGINS_DIR"
  exit 1
fi

rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR/plugins" "$SITE_DIR/features"

# Copy plugin JAR
PLUGIN_JAR=$(ls "$PROJECT_DIR/dist"/*.jar | head -n 1)
cp "$PLUGIN_JAR" "$SITE_DIR/plugins/"

# Package Feature JAR
FEATURE_JAR="$SITE_DIR/features/io.github.dbeaver.export.geojson.feature_1.0.1.jar"
jar cf "$FEATURE_JAR" -C "$PROJECT_DIR/feature" feature.xml

# Define an installable category so Eclipse/DBeaver displays the feature in
# the "Install New Software" wizard instead of only reporting uncategorized items.
cat <<EOF > "$SITE_DIR/category.xml"
<?xml version="1.0" encoding="UTF-8"?>
<site>
   <category-def name="io.github.dbeaver.export.geojson.category" label="DBeaver GeoJSON Exporter">
      <description>
         Export database query results and tables as GeoJSON FeatureCollection files.
      </description>
   </category-def>
   <feature
         id="io.github.dbeaver.export.geojson.feature"
         version="0.0.0">
      <category name="io.github.dbeaver.export.geojson.category"/>
   </feature>
</site>
EOF

echo "-> Running Eclipse Equinox P2 Publisher..."
P2_CONFIGURATION_DIR=$(mktemp -d)
DBEAVER_HOME_DIR=$(dirname "$DBEAVER_PLUGINS_DIR")
SOURCE_CONFIGURATION_DIR="$DBEAVER_HOME_DIR/configuration"

if [ ! -f "$SOURCE_CONFIGURATION_DIR/config.ini" ] || [ ! -d "$SOURCE_CONFIGURATION_DIR/org.eclipse.equinox.simpleconfigurator" ]; then
  echo "Error: DBeaver Equinox configuration not found in $SOURCE_CONFIGURATION_DIR"
  exit 1
fi

cp "$SOURCE_CONFIGURATION_DIR/config.ini" "$P2_CONFIGURATION_DIR/"
cp -a "$SOURCE_CONFIGURATION_DIR/org.eclipse.equinox.simpleconfigurator" "$P2_CONFIGURATION_DIR/"

cleanup_p2_configuration() {
  rm -rf "$P2_CONFIGURATION_DIR"
}
trap cleanup_p2_configuration EXIT

if ! java -jar "$LAUNCHER" \
  -install "$DBEAVER_HOME_DIR" \
  -configuration "$P2_CONFIGURATION_DIR" \
  -consoleLog \
  -application org.eclipse.equinox.p2.publisher.FeaturesAndBundlesPublisher \
  -metadataRepository "file:${SITE_DIR}" \
  -artifactRepository "file:${SITE_DIR}" \
  -source "$SITE_DIR" \
  -publishArtifacts \
  -compress; then
  echo "Error: Eclipse P2 publisher failed."
  find "$P2_CONFIGURATION_DIR" -type f -name '*.log' -exec sh -c 'echo "--- $1"; cat "$1"' _ {} \;
  exit 1
fi

echo "-> Applying P2 repository categories..."
if ! java -jar "$LAUNCHER" \
  -install "$DBEAVER_HOME_DIR" \
  -configuration "$P2_CONFIGURATION_DIR" \
  -consoleLog \
  -application org.eclipse.equinox.p2.publisher.CategoryPublisher \
  -metadataRepository "file:${SITE_DIR}" \
  -categoryDefinition "file:${SITE_DIR}/category.xml" \
  -compress; then
  echo "Error: Eclipse P2 category publisher failed."
  find "$P2_CONFIGURATION_DIR" -type f -name '*.log' -exec sh -c 'echo "--- $1"; cat "$1"' _ {} \;
  exit 1
fi

# Create p2.index
cat <<EOF > "$SITE_DIR/p2.index"
version = 1
metadata.repository.factory.order = content.xml,!
artifact.repository.factory.order = artifacts.xml,!
EOF

# Create landing index.html for web browsers
cat <<EOF > "$SITE_DIR/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>DBeaver GeoJSON Exporter - Update Site</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; max-width: 720px; margin: 40px auto; padding: 20px; line-height: 1.6; color: #24292e; background: #fafbfc; }
    .card { background: white; border: 1px solid #e1e4e8; border-radius: 6px; padding: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
    h1 { margin-top: 0; color: #2E7D32; display: flex; align-items: center; gap: 10px; }
    code { background: #f6f8fa; padding: 4px 8px; border-radius: 4px; font-size: 90%; }
    .url-box { background: #eef9f0; border: 1px solid #c3e6cb; border-radius: 6px; padding: 12px; margin: 20px 0; font-family: monospace; font-size: 1.1em; color: #155724; word-break: break-all; }
    ol { padding-left: 20px; }
    li { margin-bottom: 8px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>DBeaver GeoJSON Exporter</h1>
    <p>This is the official <strong>Eclipse P2 Update Site</strong> repository for the DBeaver GeoJSON Exporter plugin.</p>
    
    <h3>How to install in DBeaver:</h3>
    <ol>
      <li>Open <strong>DBeaver</strong>.</li>
      <li>Navigate to menu <strong>Help &gt; Install New Software...</strong></li>
      <li>Click the <strong>Add...</strong> button at the top right.</li>
      <li>Paste this repository URL into the <strong>Location</strong> field:</li>
    </ol>

    <div class="url-box" id="repoUrl">Loading URL...</div>

    <ol start="5">
      <li>Check the <strong>DBeaver GeoJSON Exporter</strong> checkbox.</li>
      <li>Click <strong>Next &gt; Finish</strong> and restart DBeaver when prompted.</li>
    </ol>
  </div>

  <script>
    document.getElementById('repoUrl').innerText = window.location.href;
  </script>
</body>
</html>
EOF

echo "=== P2 Update Site Generated Successfully! ==="
echo "Location: $SITE_DIR"
