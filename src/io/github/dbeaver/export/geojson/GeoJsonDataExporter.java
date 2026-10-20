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
 * Exportador DBeaver para o formato GeoJSON.
 * - Quando reprojectTo4326 == true: Gera GeoJSON RFC 7946 estrito em EPSG:4326 (WGS84) sem membro CRS.
 * - Quando reprojectTo4326 == false: Preserva coordenadas nativas e declara o membro CRS com o EPSG de origem.
 */
public class GeoJsonDataExporter extends StreamExporterAbstract {

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
        this.geoJsonWriter.setEncodeCRS(false); // Mantém geometrias limpas (CRS vai na raiz da FeatureCollection se necessário)
        this.geoJsonWriter.setForceCCW(true);   // RFC 7946 regra da mão direita
        this.wktReader = new WKTReader();
        this.wkbReader = new WKBReader();

        // Leitura de propriedades configuráveis
        Map<String, Object> properties = site.getProperties();
        if (properties != null) {
            if (properties.containsKey("force2D")) {
                Object val = properties.get("force2D");
                this.force2D = val instanceof Boolean ? (Boolean) val : Boolean.parseBoolean(String.valueOf(val));
            }
            if (properties.containsKey("reprojectTo4326")) {
                Object val = properties.get("reprojectTo4326");
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
                    || name.equals("geom") || name.equals("the_geom") || name.equals("geometry")) {
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

        // Se o usuário optou por NÃO reprojetar e o dado possui SRID definido diferente de 4326:
        // Declaramos formalmente o CRS no nível da FeatureCollection para que leitores GIS (QGIS, GDAL)
        // saibam exatamente qual o sistema de projeção correto.
        if (!reprojectTo4326 && srid != 0 && srid != 4326) {
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

        // Se ainda não detectou a coluna geométrica, tenta inspecionar os objetos da linha
        if (geometryColumnIndex == -1) {
            for (int i = 0; i < row.length; i++) {
                if (row[i] instanceof DBGeometry || row[i] instanceof Geometry) {
                    geometryColumnIndex = i;
                    break;
                }
            }
        }

        // Na primeira linha, detecta o SRID da amostra e escreve o cabeçalho apropriado
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

        // 1. Geometria
        writer.print("      \"geometry\": ");
        writeGeometry(row);
        writer.println(",");

        // 2. Propriedades (demais atributos)
        writer.println("      \"properties\": {");
        boolean firstProp = true;
        int numCols = (columns != null) ? columns.length : row.length;

        for (int i = 0; i < numCols; i++) {
            if (i == geometryColumnIndex) {
                continue; // A geometria já foi escrita no campo 'geometry'
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

                // Se já for uma string GeoJSON bruta
                if (str.startsWith("{") && str.endsWith("}")) {
                    writer.print(str);
                    return;
                }

                // Extrai prefixo SRID do PostGIS (ex: "SRID=31984;POINT(...)")
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

                // Tenta ler como WKT
                try {
                    jtsGeom = wktReader.read(str);
                    if (srid == 0) {
                        srid = jtsGeom.getSRID();
                    }
                } catch (Exception ignored) {
                    // Tenta ler como Hex WKB
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
                // 1. Reprojeção para WGS84 se configurado
                if (reprojectTo4326 && srid != 0 && srid != 4326) {
                    try {
                        DBGeometry toTransform = new DBGeometry(jtsGeom, srid);
                        DBGeometry transformed = GisTransformUtils.transformToSRID(toTransform, 4326);
                        if (transformed != null && transformed.getGeometry() != null) {
                            jtsGeom = transformed.getGeometry();
                        }
                    } catch (Exception ignored) {
                    }
                }

                // 2. Force 2D se configurado
                if (force2D) {
                    try {
                        DBGeometry db2D = new DBGeometry(jtsGeom).force2D();
                        if (db2D != null && db2D.getGeometry() != null) {
                            jtsGeom = db2D.getGeometry();
                        }
                    } catch (Exception ignored) {
                    }
                }

                // Limpa SRID para que o GeoJsonWriter não insira bloco 'crs' dentro da geometria
                // (O CRS já está definido no topo do FeatureCollection se necessário)
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
