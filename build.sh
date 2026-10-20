#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/bin"
DIST_DIR="${PROJECT_DIR}/dist"
JAR_NAME="io.github.dbeaver.export.geojson_1.0.0.jar"

echo "=========================================="
echo "    DBeaver GeoJSON Exporter Builder      "
echo "=========================================="

# Localiza o diretório de plugins do DBeaver
CANDIDATE_DIRS=(
  "$DBEAVER_HOME/plugins"
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
  echo "Erro: Não foi possível localizar os plugins do DBeaver."
  echo "Defina a variável DBEAVER_HOME apontando para o diretório de instalação do DBeaver."
  echo "Exemplo: export DBEAVER_HOME=/usr/share/dbeaver-ce"
  exit 1
fi

echo "-> Usando bibliotecas do DBeaver em: $DBEAVER_PLUGINS_DIR"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Monta o Classpath dinâmico
CP=$(find "$DBEAVER_PLUGINS_DIR" -name "*.jar" | tr '\n' ':')

echo "-> Compilando código Java..."
javac -cp "$CP" -d "$BUILD_DIR" \
    "$PROJECT_DIR"/src/io/github/dbeaver/export/geojson/GeoJsonDataExporter.java

echo "-> Empacotando JAR OSGi..."
jar cfm "${DIST_DIR}/${JAR_NAME}" \
    "${PROJECT_DIR}/META-INF/MANIFEST.MF" \
    -C "$BUILD_DIR" . \
    plugin.xml \
    icons

echo "=== Sucesso! ==="
echo "Arquivo gerado: ${DIST_DIR}/${JAR_NAME}"
echo ""
echo "Para instalar no DBeaver:"
echo "  sudo ./install.sh"
echo "E depois abra com: dbeaver -clean &"
