import 'dart:convert';
import 'dart:io' show gzip;

/// Décompresse un asset gzip et le découpe en lignes UTF-8.
List<String> gunzipLines(List<int> bytes) =>
    const LineSplitter().convert(utf8.decode(gzip.decode(bytes)));
