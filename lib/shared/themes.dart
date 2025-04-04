import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kpurple = Colors.purple;
const kblack = Colors.black;
final klgrey = Colors.grey[50];
final kdgrey = Colors.grey[85];
const kred = Colors.red;
const korange = Colors.deepOrange;
const kwhite = Colors.white;
const ktransparent = Colors.transparent;

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    colorScheme: const ColorScheme.dark(
      surface: kblack,
      primary: kwhite,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 25,
          color: kwhite,
          fontWeight: FontWeight.bold,
        ),
        bodyMedium: TextStyle(
            fontSize: 15, color: kwhite, fontWeight: FontWeight.normal),
        bodySmall: TextStyle(
            fontSize: 10, color: kwhite, fontWeight: FontWeight.normal),
      ),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    colorScheme: const ColorScheme.dark(
      surface: kwhite,
      primary: kblack,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(
          fontSize: 25,
          color: kblack,
          fontWeight: FontWeight.bold,
        ),
        bodyMedium: TextStyle(
            fontSize: 15, color: kblack, fontWeight: FontWeight.normal),
        bodySmall: TextStyle(
            fontSize: 10, color: kblack, fontWeight: FontWeight.normal),
      ),
    ),
  );
}
