import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/app_database.dart';
import 'ui/home_screen.dart';

class AvancoApp extends StatelessWidget {
  final AppDatabase database;

  const AvancoApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF038A99);
    const secondary = Color(0xFF4FA5AE);
    const tertiary = Color(0xFF8CC9CE);
    const background = Color(0xFFF3FAFA);
    const surface = Color(0xFFF3FAFA);
    const onSurface = Color(0xFF1D1D1D);
    const outline = Color(0xFFB3DFE9);

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      tertiary: tertiary,
      onTertiary: Colors.white,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Avanço',
      restorationScopeId: 'test',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        textTheme: GoogleFonts.ubuntuTextTheme(),
        scaffoldBackgroundColor: background,
        dividerColor: outline,
        cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0),
      ),
      home: HomeScreen(database: database),
    );
  }
}
