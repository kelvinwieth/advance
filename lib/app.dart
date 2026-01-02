import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/app_database.dart';
import 'ui/home_screen.dart';

class AvancoApp extends StatelessWidget {
  final AppDatabase database;

  const AvancoApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F5BFF),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Avanço',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0),
      ),
      home: HomeScreen(database: database),
    );
  }
}
