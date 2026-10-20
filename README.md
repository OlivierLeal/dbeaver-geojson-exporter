# DBeaver GeoJSON Exporter

A DBeaver data-transfer plugin that exports query results and database tables as GeoJSON `FeatureCollection` files.

The exporter accepts spatial values supplied by the database driver as well as WKT, WKB, and EWKB. It is intended for PostGIS, SpatiaLite, MySQL Spatial, Oracle Spatial, and other DBeaver connections that expose geometry values.

## Features

- Adds **GeoJSON** to DBeaver's **Export Data** wizard.
- Writes GeoJSON `FeatureCollection` output.
- Detects common geometry columns such as `geom`, `the_geom`, and `geometry`.
- Places non-spatial columns in each feature's `properties` member.
- Reprojects to WGS 84 (EPSG:4326) by default, as required by RFC 7946.
- Can preserve the source coordinate system and write its CRS metadata.
- Can remove Z and M coordinates.
- Writes polygon rings using the RFC 7946 right-hand rule.

## Example

Given the following query:

```sql
SELECT id, name, population, the_geom FROM cities;
```

the exporter produces output like this:

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

## Installation

### Update site

In DBeaver, open **Help > Install New Software...**, select **Add...**, and enter the update-site URL:

```text
https://olivierleal.github.io/dbeaver-geojson-exporter/
```

Select **DBeaver GeoJSON Exporter**, finish the installation, and restart DBeaver when prompted.

### Release JAR

Download `io.github.dbeaver.export.geojson_1.0.1.jar` from the [Releases](https://github.com/OlivierLeal/dbeaver-geojson-exporter/releases) page. Copy it into DBeaver's `plugins` directory and add this line to `configuration/org.eclipse.equinox.simpleconfigurator/bundles.info`:

```text
io.github.dbeaver.export.geojson,1.0.1,plugins/io.github.dbeaver.export.geojson_1.0.1.jar,4,false
```

Close every DBeaver window and start it once with the `-clean` flag so Eclipse rebuilds its plugin registry.

```bash
dbeaver -clean
```

On macOS, use:

```bash
open -a DBeaver --args -clean
```

On Windows, start `dbeaver.exe` with `-clean`.

### Build and install from source

Requirements:

- DBeaver CE or PRO
- JDK 25 (required by the current DBeaver CE build)

```bash
git clone https://github.com/olivier/dbeaver-geojson-exporter.git
cd dbeaver-geojson-exporter
./scripts/build.sh
sudo ./scripts/install.sh
```

Then close DBeaver and run:

```bash
dbeaver -clean
```

For a non-standard DBeaver installation, set `DBEAVER_HOME` before building and installing:

```bash
export DBEAVER_HOME=/path/to/dbeaver
./scripts/build.sh
sudo -E ./scripts/install.sh
dbeaver -clean
```

On Windows, run the PowerShell scripts from an elevated PowerShell session when DBeaver is installed under `Program Files`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
Start-Process dbeaver.exe -ArgumentList "-clean"
```

If DBeaver reports `Processor 'stream.geojson' not found in 'Files'`, it was started with an outdated plugin registry. Close every instance and run it once with `-clean`.

## Usage

1. Run a query that includes a spatial column.
2. In the result grid, choose **Export Data**.
3. Under **Files**, select **GeoJSON**.
4. Choose the output path and proceed.

The format settings are:

- **Reproject to WGS84 (EPSG:4326)**: converts coordinates to longitude and latitude. Enabled by default.
- **Force 2D coordinates**: removes Z and M dimensions.
- **File extension**: defaults to `geojson`.

## Uninstall

On Linux or macOS:

```bash
sudo ./scripts/uninstall.sh
dbeaver -clean
```

On Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
Start-Process dbeaver.exe -ArgumentList "-clean"
```

## Development

Build the plugin with:

```bash
./scripts/build.sh
```

The generated bundle is `dist/io.github.dbeaver.export.geojson_1.0.1.jar`.

## License

This project is licensed under the [Apache License 2.0](LICENSE).
