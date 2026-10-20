# DBeaver GeoJSON Exporter Plugin 🗺️

[![CI - Build and Test](https://github.com/olivier/dbeaver-geojson-exporter/actions/workflows/ci.yml/badge.svg)](https://github.com/olivier/dbeaver-geojson-exporter/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Java](https://img.shields.io/badge/Java-17%20%7C%2021-orange.svg)](https://adoptium.net/)
[![DBeaver](https://img.shields.io/badge/DBeaver-CE%20%7C%20PRO-2E7D32.svg)](https://dbeaver.io/)
[![GeoJSON](https://img.shields.io/badge/GeoJSON-RFC_7946-4CAF50.svg)](https://tools.ietf.org/html/rfc7946)

A native export plugin for **[DBeaver](https://dbeaver.io/)** that allows you to directly export query results and database tables containing spatial data into standard **GeoJSON (`FeatureCollection`)** files.

Works seamlessly with **PostGIS**, **SpatiaLite**, **MySQL Spatial**, **Oracle Spatial**, WKT, WKB, and EWKB.

---

## ⚡ Highlights & Features

* 📍 **Native Data Transfer Wizard Integration:** Appears directly as **GeoJSON** in DBeaver's *Export Data* formats list.
* 🌐 **Automatic WGS 84 (EPSG:4326) Reprojection:** Follows the **RFC 7946** standard by automatically reprojection projected coordinates (e.g., UTM, SIRGAS 2000, Web Mercator) into standard `[longitude, latitude]` degrees using DBeaver's built-in geodetic engine.
* 🧭 **Smart CRS Handling:**
  * **When Reprojection is enabled (`true`):** Strict RFC 7946 adherence (no legacy `crs` block).
  * **When Reprojection is disabled (`false`):** Coordinates remain in native system (e.g., meters) and an OGC-compliant `crs` header (`urn:ogc:def:crs:EPSG::<SRID>`) is added so QGIS and GIS viewers automatically know the exact projection.
* 📦 **Automatic Feature & Properties Mapping:** Automatically identifies the spatial column (`geom`, `the_geom`, `geometry`, etc.) for the `geometry` field, and packs all other columns into the `properties` dictionary.
* 📐 **2D Enforcement Option (`force2D`):** Strips Z/M dimensions if desired to keep files compact and web-ready.
* 🔄 **Polygon Orientation (RFC 7946):** Enforces the right-hand rule (counter-clockwise exterior rings) for standard polygon encoding.

---

## 📄 Example Output

Exporting a query like `SELECT id, name, population, the_geom FROM cities`:

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

---

## 🚀 Installation

### Option 1: Quick Install (Pre-built Release)

Download the latest `.jar` from the **[Releases](https://github.com/olivier/dbeaver-geojson-exporter/releases)** tab and follow the instructions for your OS:

<details open>
<summary><b>🐧 Linux</b></summary>

```bash
# Copy JAR to DBeaver plugins
sudo cp io.github.dbeaver.export.geojson_1.0.0.jar /usr/share/dbeaver-ce/plugins/

# Register bundle into Equinox configurator
echo "io.github.dbeaver.export.geojson,1.0.0,plugins/io.github.dbeaver.export.geojson_1.0.0.jar,4,false" | sudo tee -a /usr/share/dbeaver-ce/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info

# Launch with -clean
dbeaver -clean &
```
</details>

<details>
<summary><b>🍎 macOS</b></summary>

```bash
# Path inside the macOS DBeaver app bundle
DBEAVER_APP="/Applications/DBeaver.app/Contents/Eclipse"

# Copy JAR
cp io.github.dbeaver.export.geojson_1.0.0.jar "$DBEAVER_APP/plugins/"

# Register bundle
echo "io.github.dbeaver.export.geojson,1.0.0,plugins/io.github.dbeaver.export.geojson_1.0.0.jar,4,false" >> "$DBEAVER_APP/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"

# Launch DBeaver
open -a DBeaver --args -clean
```
</details>

<details>
<summary><b>🪟 Windows (PowerShell as Administrator)</b></summary>

```powershell
$DBeaverDir = "$env:ProgramFiles\DBeaver"

# Copy JAR
Copy-Item "io.github.dbeaver.export.geojson_1.0.0.jar" -Destination "$DBeaverDir\plugins\"

# Register bundle
Add-Content -Path "$DBeaverDir\configuration\org.eclipse.equinox.simpleconfigurator\bundles.info" -Value "`nio.github.dbeaver.export.geojson,1.0.0,plugins/io.github.dbeaver.export.geojson_1.0.0.jar,4,false"

# Launch DBeaver with clean flag
Start-Process "$DBeaverDir\dbeaver.exe" -ArgumentList "-clean"
```
</details>

---

### Option 2: Automated Install from Source

Clone the repository and run the installer for your operating system:

* **Linux / macOS:**
  ```bash
  git clone https://github.com/olivier/dbeaver-geojson-exporter.git
  cd dbeaver-geojson-exporter
  ./scripts/build.sh
  sudo ./scripts/install.sh
  dbeaver -clean &
  ```

* **Windows (PowerShell as Administrator):**
  ```powershell
  git clone https://github.com/olivier/dbeaver-geojson-exporter.git
  cd dbeaver-geojson-exporter
  powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
  ```

---

## 🛠️ Usage in DBeaver

1. Open **DBeaver** and execute any query with spatial data (e.g. `SELECT * FROM my_spatial_table;`).
2. Right-click anywhere on the Results Grid > **Export Data**.
3. Choose **GeoJSON** from the format list and click **Next**.
4. In the **Format Settings** screen, you can customize:
   * **`Reproject to WGS84 (EPSG:4326)`** (`true` / `false`): Converts coordinates to WGS 84.
   * **`Force 2D coordinates`** (`true` / `false`): Converts 3D/4D geometries to 2D `[X, Y]`.
   * **`File extension`**: Output extension (default: `geojson`).
5. Choose destination folder and click **Proceed**!

---

## 🏗️ Building & Development

### Prerequisites
- Java JDK 17 or 21.
- DBeaver CE or PRO installed locally (or set `DBEAVER_HOME`).

### Build Command
```bash
./scripts/build.sh
```
The compiled OSGi bundle will be located at `dist/io.github.dbeaver.export.geojson_1.0.0.jar`.

---

## 🗑️ Uninstalling

* **Linux / macOS:**
  ```bash
  sudo ./scripts/uninstall.sh
  dbeaver -clean &
  ```

* **Windows (PowerShell as Administrator):**
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
  ```

---

## 🤝 Contributing

Contributions are very welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and development process.

---

## ⚖️ License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.
