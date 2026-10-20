#!/usr/bin/env bash
set -e

DBEAVER_DIR="/usr/share/dbeaver-ce"
BUNDLES_INFO="${DBEAVER_DIR}/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
PLUGIN_TARGET="${DBEAVER_DIR}/plugins/io.github.dbeaver.export.geojson_1.0.0.jar"

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como superusuário (root):"
  echo "  sudo ./uninstall.sh"
  exit 1
fi

echo "=== Desinstalando DBeaver GeoJSON Exporter ==="

# Remove o arquivo JAR do diretório de plugins
if [ -f "$PLUGIN_TARGET" ]; then
  echo "-> Removendo plugin JAR de ${PLUGIN_TARGET}..."
  rm -f "$PLUGIN_TARGET"
fi

# Remove da pasta dropins caso ainda exista
rm -f "${DBEAVER_DIR}/dropins/io.github.dbeaver.export.geojson_1.0.0.jar" 2>/dev/null || true

# Remove a entrada do bundles.info
if [ -f "$BUNDLES_INFO" ] && grep -q "io.github.dbeaver.export.geojson" "$BUNDLES_INFO"; then
  echo "-> Removendo registro do Equinox bundles.info..."
  sed -i '/io\.github\.dbeaver\.export\.geojson/d' "$BUNDLES_INFO"
fi

echo "=== Plugin desinstalado com sucesso! ==="
echo "Para aplicar a alteração, inicie o DBeaver com: dbeaver -clean"
