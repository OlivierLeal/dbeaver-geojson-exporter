# DBeaver GeoJSON Exporter

**Português** | [English](README.md)

Um plugin de transferência de dados do DBeaver que exporta resultados de consultas e tabelas de banco de dados como arquivos GeoJSON `FeatureCollection`.

O exporter aceita valores espaciais fornecidos pelo driver do banco de dados, além de WKT, WKB e EWKB. Ele foi desenvolvido para PostGIS, SpatiaLite, MySQL Spatial, Oracle Spatial e outras conexões do DBeaver que disponibilizam valores de geometria.

## Recursos

- Adiciona **GeoJSON** ao assistente **Export Data** do DBeaver.
- Gera arquivos GeoJSON no formato `FeatureCollection`.
- Detecta colunas geométricas comuns, como `geom`, `the_geom` e `geometry`.
- Coloca as colunas não espaciais no objeto `properties` de cada feature.
- Reprojeta para WGS 84 (EPSG:4326) por padrão, conforme o RFC 7946.
- Permite preservar o sistema de coordenadas de origem e gravar seu metadata CRS.
- Pode remover as coordenadas Z e M.
- Gera anéis de polígonos seguindo a regra de orientação do RFC 7946.

## Instalação pelo update site

No DBeaver, abra **Help > Install New Software...**, clique em **Add...** e informe:

```text
https://olivierleal.github.io/dbeaver-geojson-exporter/
```

Selecione **DBeaver GeoJSON Exporter**, conclua a instalação e reinicie o DBeaver quando solicitado.

O update site publica o plugin compilado para Java 17, portanto ele pode ser carregado por instalações do DBeaver que utilizem Java 17 ou superior. Se o DBeaver tiver uma instalação antiga do plugin em cache, remova essa instalação, recarregue o update site e instale a versão atual novamente.

## Uso

1. Execute uma consulta que contenha uma coluna espacial.
2. Na grade de resultados, escolha **Export Data**.
3. Em **Files**, selecione **GeoJSON**.
4. Escolha o caminho do arquivo e prossiga.

As configurações do formato são:

- **Reproject to WGS84 (EPSG:4326)**: converte as coordenadas para longitude e latitude. Está habilitada por padrão. Para manter a geometria no sistema de coordenadas original, **desmarque essa opção**. Quando a reprojeção está desabilitada, o exporter preserva as coordenadas nativas e grava o metadata do CRS EPSG de origem quando ele está disponível.
- **Force 2D coordinates**: remove as dimensões Z e M.
- **File extension**: define a extensão do arquivo; o padrão é `geojson`.

## Exemplo

Dada a consulta:

```sql
SELECT id, name, population, the_geom FROM cities;
```

O exporter gera uma estrutura semelhante a:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-46.633308, -23.55052]
      },
      "properties": {
        "id": 1,
        "name": "São Paulo",
        "population": 12300000
      }
    }
  ]
}
```

## Compilação e instalação a partir do código-fonte

Requisitos:

- DBeaver CE ou PRO
- JDK 25 para compilar contra as bibliotecas atuais do DBeaver

O build usa `--release 17`, mantendo o plugin compatível com instalações do DBeaver que utilizem Java 17 ou superior.

```bash
git clone https://github.com/OlivierLeal/dbeaver-geojson-exporter.git
cd dbeaver-geojson-exporter
./scripts/build.sh
sudo ./scripts/install.sh
```

Depois, feche todas as janelas do DBeaver e execute:

```bash
dbeaver -clean
```

Para uma instalação do DBeaver em outro caminho:

```bash
export DBEAVER_HOME=/caminho/para/dbeaver
./scripts/build.sh
sudo -E ./scripts/install.sh
dbeaver -clean
```

No Windows, execute os scripts PowerShell em uma sessão elevada:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
Start-Process dbeaver.exe -ArgumentList "-clean"
```

Se o DBeaver informar `Processor 'stream.geojson' not found in 'Files'`, feche todas as instâncias e inicie-o uma vez com a opção `-clean`.

## JAR da release

Baixe `io.github.dbeaver.export.geojson_1.0.1.jar` na página de [Releases](https://github.com/OlivierLeal/dbeaver-geojson-exporter/releases). Copie o arquivo para o diretório `plugins` do DBeaver e adicione esta linha a `configuration/org.eclipse.equinox.simpleconfigurator/bundles.info`:

```text
io.github.dbeaver.export.geojson,1.0.1,plugins/io.github.dbeaver.export.geojson_1.0.1.jar,4,false
```

Feche todas as janelas do DBeaver e inicie-o uma vez com `-clean`.

## Desinstalação

No Linux ou macOS:

```bash
sudo ./scripts/uninstall.sh
dbeaver -clean
```

No Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
Start-Process dbeaver.exe -ArgumentList "-clean"
```

## Desenvolvimento

Compile o plugin com:

```bash
./scripts/build.sh
```

O bundle gerado fica em `dist/io.github.dbeaver.export.geojson_1.0.1.jar`.

Execute os testes do exporter com:

```bash
./scripts/test.sh
```

Os testes usam as bibliotecas instaladas do DBeaver e cobrem parsing de WKT,
metadata de CRS nativo, geometrias nulas e compatibilidade de bytecode com Java 17.

## Licença

Este projeto está licenciado sob a [Apache License 2.0](LICENSE).
