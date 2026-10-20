#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAR_FILE="${PROJECT_DIR}/dist/io.github.dbeaver.export.geojson_1.0.0.jar"
DBEAVER_DIR="/usr/share/dbeaver-ce"
BUNDLES_INFO="${DBEAVER_DIR}/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
PLUGIN_TARGET="${DBEAVER_DIR}/plugins/io.github.dbeaver.export.geojson_1.0.0.jar"
BUNDLE_ENTRY="io.github.dbeaver.export.geojson,1.0.0,plugins/io.github.dbeaver.export.geojson_1.0.0.jar,4,false"

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como sudo:"
  echo "  sudo ./install.sh"
  exit 1
fi

if [ ! -f "$JAR_FILE" ]; then
  echo "Erro: JAR não encontrado em $JAR_FILE. Execute ./build.sh primeiro."
  exit 1
fi

echo "-> Instalando plugin em ${PLUGIN_TARGET}..."
cp "$JAR_FILE" "$PLUGIN_TARGET"

# Remove cópia antiga de dropins se existir
rm -f "${DBEAVER_DIR}/dropins/io.github.dbeaver.export.geojson_1.0.0.jar" 2>/dev/null || true

# Registra no simpleconfigurator (bundles.info)
if ! grep -q "io.github.dbeaver.export.geojson" "$BUNDLES_INFO"; then
  echo "-> Registrando plugin no Equinox simpleconfigurator..."
  cp "$BUNDLES_INFO" "${BUNDLES_INFO}.bak"
  echo "$BUNDLE_ENTRY" >> "$BUNDLES_INFO"
else
  echo "-> Plugin já registrado no bundles.info."
fi

echo "=== Instalação concluída com sucesso! ==="
echo "Inicie o DBeaver com: dbeaver -clean"
