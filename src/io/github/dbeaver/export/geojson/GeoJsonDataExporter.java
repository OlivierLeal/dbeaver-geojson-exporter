package io.github.dbeaver.export.geojson;

import org.jkiss.dbeaver.DBException;
import org.jkiss.dbeaver.model.data.DBDAttributeBinding;
import org.jkiss.dbeaver.model.data.json.JSONUtils;
import org.jkiss.dbeaver.model.exec.DBCResultSet;
import org.jkiss.dbeaver.model.exec.DBCSession;
import org.jkiss.dbeaver.model.gis.DBGeometry;
import org.jkiss.dbeaver.model.gis.GisTransformUtils;
import org.jkiss.dbeaver.model.runtime.DBRProgressMonitor;
import org.jkiss.dbeaver.tools.transfer.stream.IStreamDataExporterSite;
import org.jkiss.dbeaver.tools.transfer.stream.exporter.StreamExporterAbstract;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.io.WKBReader;
import org.locationtech.jts.io.WKTReader;
import org.locationtech.jts.io.geojson.GeoJsonWriter;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.Map;

/**
 * DBeaver Data Exporter for GeoJSON format.
 * <p>
 * Complies with the RFC 7946 GeoJSON specification:
 * <ul>
 *   <li>When {@code reprojectTo4326} is true: reprojects geometries to WGS 84 (EPSG:4326) and omits the legacy 'crs' member.</li>
 *   <li>When {@code reprojectTo4326} is false: preserves native coordinates and declares the OGC CRS member on the FeatureCollection.</li>
 *   <li>Enforces right-hand rule (counter-clockwise) for polygon outer rings.</li>
 * </ul>
 */
public class GeoJsonDataExporter extends StreamExporterAbstract {

    private static final String PROP_FORCE_2D = "force2D";
    private static final String PROP_REPROJECT_TO_4326 = "reprojectTo4326";
    private static final String GEOMETRY_DEFAULT_KEY = "geometry";
    private static final int WGS84_SRID = 4326;

    private PrintWriter writer;
    private DBDAttributeBinding[] columns;
    private int geometryColumnIndex = -1;
    private boolean headerWritten = false;
    private boolean firstFeature = true;
    private boolean force2D = true;
    private boolean reprojectTo4326 = true;
    private int detectedDatasetSRID = 0;
    private GeoJsonWriter geoJsonWriter;
    private WKTReader wktReader;
    private WKBReader wkbReader;

    @Override
    public void init(IStreamDataExporterSite site) throws DBException {
        super.init(site);
        this.writer = site.getWriter();
        this.geoJsonWriter = new GeoJsonWriter();
        this.geoJsonWriter.setEncodeCRS(false); // Clean geometries (CRS placed at FeatureCollection root if needed)
        this.geoJsonWriter.setForceCCW(true);   // RFC 7946 right-hand rule
        this.wktReader = new WKTReader();
        this.wkbReader = new WKBReader();

        // Read user-defined configuration properties
        Map<String, Object> properties = site.getProperties();
        if (properties != null) {
            if (properties.containsKey(PROP_FORCE_2D)) {
                Object val = properties.get(PROP_FORCE_2D);
                this.force2D = val instanceof Boolean ? (Boolean) val : Boolean.parseBoolean(String.valueOf(val));
            }
            if (properties.containsKey(PROP_REPROJECT_TO_4326)) {
                Object val = properties.get(PROP_REPROJECT_TO_4326);
                this.reprojectTo4326 = val instanceof Boolean ? (Boolean) val : Boolean.parseBoolean(String.valueOf(val));
            }
        }

        this.columns = site.getAttributes();
        if (this.columns != null) {
            detectGeometryColumn();
        }
    }

    private void detectGeometryColumn() {
        if (columns == null) {
            return;
        }
        for (int i = 0; i < columns.length; i++) {
            DBDAttributeBinding attr = columns[i];
            String typeName = attr.getTypeName() != null ? attr.getTypeName().toLowerCase() : "";
            String name = attr.getName() != null ? attr.getName().toLowerCase() : "";

            if (typeName.contains("geometry") || typeName.contains("geography") || typeName.contains("spatial")
                    || typeName.equals("point") || typeName.equals("polygon") || typeName.equals("linestring")
                    || name.equals("geom") || name.equals("the_geom") || name.equals(GEOMETRY_DEFAULT_KEY)) {
                geometryColumnIndex = i;
                break;
            }
        }
    }

    @Override
    public void exportHeader(DBCSession session) throws DBException, IOException {
        this.columns = getSite().getAttributes();
        if (this.columns != null && geometryColumnIndex == -1) {
            detectGeometryColumn();
        }
        this.writer = getWriter();
        this.headerWritten = false;
        this.firstFeature = true;
    }

    private void writeFeatureCollectionHeader(int srid) {
        if (headerWritten) {
            return;
        }

        writer.println("{");
        writer.println("  \"type\": \"FeatureCollection\",");

        // When reprojection is disabled and native SRID is not WGS84, declare OGC CRS metadata
        // at the FeatureCollection root so GIS tools (QGIS, GDAL, ArcGIS) correctly identify the projection.
        if (!reprojectTo4326 && srid != 0 && srid != WGS84_SRID) {
            writer.println("  \"crs\": {");
            writer.println("    \"type\": \"name\",");
            writer.println("    \"properties\": {");
            writer.println("      \"name\": \"urn:ogc:def:crs:EPSG::" + srid + "\"");
            writer.println("    }");
            writer.println("  },");
        }

        writer.println("  \"features\": [");
        headerWritten = true;
    }

    @Override
    public void exportRow(DBCSession session, DBCResultSet resultSet, Object[] row) throws DBException, IOException {
        if (row == null) {
            return;
        }

        if (this.columns == null) {
            this.columns = getSite().getAttributes();
        }

        // Lazy fallback detection of geometry column by inspecting row object instances
        if (geometryColumnIndex == -1) {
            for (int i = 0; i < row.length; i++) {
                if (row[i] instanceof DBGeometry || row[i] instanceof Geometry) {
                    geometryColumnIndex = i;
                    break;
                }
            }
        }

        // On the first row, determine the spatial reference system and output the FeatureCollection header
        if (!headerWritten) {
            int srid = extractSRID(row);
            this.detectedDatasetSRID = srid;
            writeFeatureCollectionHeader(srid);
        }

        if (!firstFeature) {
            writer.println(",");
        }
        firstFeature = false;

        writer.println("    {");
        writer.println("      \"type\": \"Feature\",");

        // 1. Geometry serialization
        writer.print("      \"geometry\": ");
        writeGeometry(row);
        writer.println(",");

        // 2. Alphanumeric properties
        writer.println("      \"properties\": {");
        boolean firstProp = true;
        int numCols = (columns != null) ? columns.length : row.length;

        for (int i = 0; i < numCols; i++) {
            if (i == geometryColumnIndex) {
                continue; // Geometry column is already mapped into the 'geometry' member
            }

            if (!firstProp) {
                writer.println(",");
            }
            firstProp = false;

            String colName = (columns != null && i < columns.length) ? columns[i].getName() : "col_" + i;
            Object cellValue = (i < row.length) ? row[i] : null;
            DBDAttributeBinding attr = (columns != null && i < columns.length) ? columns[i] : null;

            writer.print("        \"" + JSONUtils.escapeJsonString(colName) + "\": ");
            writePropertyValue(attr, cellValue);
        }
        writer.println();
        writer.println("      }");
        writer.print("    }");
    }

    private int extractSRID(Object[] row) {
        if (geometryColumnIndex < 0 || geometryColumnIndex >= row.length || row[geometryColumnIndex] == null) {
            return 0;
        }
        Object geomObj = row[geometryColumnIndex];

        if (geomObj instanceof DBGeometry) {
            return ((DBGeometry) geomObj).getSRID();
        } else if (geomObj instanceof Geometry) {
            return ((Geometry) geomObj).getSRID();
        } else if (geomObj != null) {
            String str = geomObj.toString().trim();
            if (str.startsWith("SRID=") || str.startsWith("srid=")) {
                int scIndex = str.indexOf(';');
                if (scIndex > 0) {
                    try {
                        return Integer.parseInt(str.substring(5, scIndex));
                    } catch (Exception ignored) {
                    }
                }
            }
        }
        return 0;
    }

    private void writeGeometry(Object[] row) {
        if (geometryColumnIndex < 0 || geometryColumnIndex >= row.length || row[geometryColumnIndex] == null) {
            writer.print("null");
            return;
        }

        Object geomObj = row[geometryColumnIndex];

        try {
            Geometry jtsGeom = null;
            int srid = detectedDatasetSRID;

            if (geomObj instanceof DBGeometry) {
                DBGeometry dbGeom = (DBGeometry) geomObj;
                srid = dbGeom.getSRID();
                jtsGeom = dbGeom.getGeometry();
            } else if (geomObj instanceof Geometry) {
                jtsGeom = (Geometry) geomObj;
                srid = jtsGeom.getSRID();
            } else if (geomObj instanceof byte[]) {
                try {
                    jtsGeom = wkbReader.read((byte[]) geomObj);
                    srid = jtsGeom.getSRID();
                } catch (Exception ignored) {
                }
            } else if (geomObj != null) {
                String str = geomObj.toString().trim();

                // If already formatted as raw GeoJSON string
                if (str.startsWith("{") && str.endsWith("}")) {
                    writer.print(str);
                    return;
                }

                // Parse PostGIS EWKT prefix (e.g., "SRID=31984;POINT(...)")
                if (str.startsWith("SRID=") || str.startsWith("srid=")) {
                    int scIndex = str.indexOf(';');
                    if (scIndex > 0) {
                        try {
                            srid = Integer.parseInt(str.substring(5, scIndex));
                        } catch (Exception ignored) {
                        }
                        str = str.substring(scIndex + 1).trim();
                    }
                }

                // Attempt WKT parsing
                try {
                    jtsGeom = wktReader.read(str);
                    if (srid == 0) {
                        srid = jtsGeom.getSRID();
                    }
                } catch (Exception ignored) {
                    // Fallback to Hex EWKB parsing
                    try {
                        byte[] bytes = WKBReader.hexToBytes(str);
                        jtsGeom = wkbReader.read(bytes);
                        if (srid == 0) {
                            srid = jtsGeom.getSRID();
                        }
                    } catch (Exception ignored2) {
                    }
                }
            }

            if (jtsGeom != null) {
                // 1. Reproject to WGS84 (EPSG:4326) if enabled and coordinates are in a projected system
                if (reprojectTo4326 && srid != 0 && srid != WGS84_SRID) {
                    try {
                        DBGeometry toTransform = new DBGeometry(jtsGeom, srid);
                        DBGeometry transformed = GisTransformUtils.transformToSRID(toTransform, WGS84_SRID);
                        if (transformed != null && transformed.getGeometry() != null) {
                            jtsGeom = transformed.getGeometry();
                        }
                    } catch (Exception ignored) {
                        // Fallback: preserve original geometry if transformation fails
                    }
                }

                // 2. Force 2D if enabled
                if (force2D) {
                    try {
                        DBGeometry db2D = new DBGeometry(jtsGeom).force2D();
                        if (db2D != null && db2D.getGeometry() != null) {
                            jtsGeom = db2D.getGeometry();
                        }
                    } catch (Exception ignored) {
                    }
                }

                // Clear JTS SRID to ensure clean geometry payload without inner CRS blocks
                jtsGeom.setSRID(0);

                String geoJsonString = geoJsonWriter.write(jtsGeom);
                writer.print(geoJsonString);
            } else {
                writer.print("null");
            }
        } catch (Exception e) {
            writer.print("null");
        }
    }

    private void writePropertyValue(DBDAttributeBinding attr, Object value) {
        if (value == null) {
            writer.print("null");
            return;
        }

        if (value instanceof Number || value instanceof Boolean) {
            writer.print(value.toString());
            return;
        }

        String strValue = null;
        if (attr != null) {
            try {
                strValue = getValueDisplayString(attr, value);
            } catch (Exception ignored) {
            }
        }

        if (strValue == null) {
            strValue = value.toString();
        }

        writer.print("\"" + JSONUtils.escapeJsonString(strValue) + "\"");
    }

    @Override
    public void exportFooter(DBRProgressMonitor monitor) throws IOException {
        if (!headerWritten) {
            writeFeatureCollectionHeader(0);
        }
        writer.println();
        writer.println("  ]");
        writer.println("}");
        writer.flush();
    }

    @Override
    public void dispose() {
        this.writer = null;
        this.columns = null;
        try {
            super.dispose();
        } catch (IOException ignored) {
        }
    }
}
