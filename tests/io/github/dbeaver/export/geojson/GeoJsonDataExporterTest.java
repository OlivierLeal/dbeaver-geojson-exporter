package io.github.dbeaver.export.geojson;

import org.locationtech.jts.io.geojson.GeoJsonWriter;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Field;
import java.lang.reflect.Method;

public final class GeoJsonDataExporterTest {
    private GeoJsonDataExporterTest() {
    }

    public static void main(String[] args) throws Exception {
        testWktPoint();
        testEwktPreservesNativeCrs();
        testNullGeometry();
        System.out.println("All GeoJSON exporter tests passed.");
    }

    private static void testWktPoint() throws Exception {
        GeoJsonDataExporter exporter = newExporter();
        String output = writeGeometry(exporter, new Object[]{"POINT (1 2)"});

        assertContains(output, "\"type\":\"Point\"", "WKT geometry type");
        assertContains(output, "\"coordinates\":[1,2]", "WKT coordinates");
    }

    private static void testEwktPreservesNativeCrs() throws Exception {
        GeoJsonDataExporter exporter = newExporter();
        setField(exporter, "reprojectTo4326", false);
        StringWriter output = new StringWriter();
        setField(exporter, "writer", new PrintWriter(output));
        invoke(exporter, "writeFeatureCollectionHeader", new Class<?>[]{int.class}, 31984);

        assertContains(output.toString(), "\"name\": \"urn:ogc:def:crs:EPSG::31984\"",
                "native CRS metadata");
    }

    private static void testNullGeometry() throws Exception {
        GeoJsonDataExporter exporter = newExporter();
        String output = writeGeometry(exporter, new Object[]{null});

        assertEquals("null", output, "null geometry");
    }

    private static GeoJsonDataExporter newExporter() throws Exception {
        GeoJsonDataExporter exporter = new GeoJsonDataExporter();
        GeoJsonWriter geoJsonWriter = new GeoJsonWriter();
        geoJsonWriter.setEncodeCRS(false);
        setField(exporter, "geoJsonWriter", geoJsonWriter);
        setField(exporter, "wktReader", new org.locationtech.jts.io.WKTReader());
        setField(exporter, "wkbReader", new org.locationtech.jts.io.WKBReader());
        setField(exporter, "geometryColumnIndex", 0);
        setField(exporter, "force2D", true);
        setField(exporter, "reprojectTo4326", false);
        return exporter;
    }

    private static String writeGeometry(GeoJsonDataExporter exporter, Object[] row) throws Exception {
        StringWriter output = new StringWriter();
        setField(exporter, "writer", new PrintWriter(output));
        invoke(exporter, "writeGeometry", new Class<?>[]{Object[].class}, (Object) row);
        return output.toString();
    }

    private static void invoke(Object target, String name, Class<?>[] parameterTypes, Object... args)
            throws Exception {
        Method method = target.getClass().getDeclaredMethod(name, parameterTypes);
        method.setAccessible(true);
        method.invoke(target, args);
    }

    private static void setField(Object target, String name, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(name);
        field.setAccessible(true);
        field.set(target, value);
    }

    private static void assertContains(String actual, String expected, String description) {
        if (!actual.contains(expected)) {
            throw new AssertionError(description + ": expected to find " + expected + " in " + actual);
        }
    }

    private static void assertEquals(String expected, String actual, String description) {
        if (!expected.equals(actual)) {
            throw new AssertionError(description + ": expected " + expected + " but got " + actual);
        }
    }
}
