// Die EINE Theme-Quelle der App — von main.dart UND vom
// Theme-Guard-Test (test/seo_theme_css_test.dart) importiert.
//
// Genau diese Teilung ist der Vertrag der Theme-Brücke: Der Guard
// vergleicht das generierte CSS mit dem Theme, das ER baut. Nur wenn
// die App dieselbe Funktion nutzt, bewacht der Guard wirklich das, was
// auf dem Bildschirm ist — ein zweites, inline in MaterialApp
// definiertes Theme könnte lautlos driften.
import 'package:flutter/material.dart';

ThemeData buildLightTheme() =>
    ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true);

ThemeData buildDarkTheme() => ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
      useMaterial3: true,
    );
