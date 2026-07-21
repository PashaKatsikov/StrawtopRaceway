import 'package:flutter/material.dart';

/// Central design system for Strawtop Raceway.
/// A cohesive cartoon look: deep navy backdrop, chunky rounded cards,
/// thick outlines, vibrant candy accents and soft drop shadows.
class AppColors {
  static const Color navyDeep = Color(0xFF10173A);
  static const Color navy = Color(0xFF1B2A6B);
  static const Color navyLight = Color(0xFF2C3E8F);

  static const Color panel = Color(0xFF223066);
  static const Color panelLight = Color(0xFF2E3F82);

  static const Color red = Color(0xFFFF4D4D);
  static const Color redDark = Color(0xFFD32F2F);
  static const Color yellow = Color(0xFFFFD23F);
  static const Color yellowDark = Color(0xFFF5A623);
  static const Color blue = Color(0xFF2D9CDB);
  static const Color blueDark = Color(0xFF1B6FB3);
  static const Color green = Color(0xFF3DDC84);
  static const Color greenDark = Color(0xFF23A65A);
  static const Color purple = Color(0xFF9B5DE5);
  static const Color pink = Color(0xFFFF6EC7);

  static const Color ink = Color(0xFF0C1130);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFB9C2E8);

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy, navyDeep],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [yellow, yellowDark],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green, greenDark],
  );

  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [red, redDark],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue, blueDark],
  );
}

class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
  static const double pill = 999;
}

class AppText {
  static const String family = 'Baloo';

  static TextStyle title(double size, {Color color = AppColors.textLight}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 0.5,
        height: 1.05,
      );

  static TextStyle body(double size,
          {Color color = AppColors.textLight,
          FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color);
}

class AppTheme {
  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.navyDeep,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme().apply(
        bodyColor: AppColors.textLight,
        displayColor: AppColors.textLight,
      ),
    );
  }
}

/// Reusable outlined text with a cartoon stroke.
class StrokeText extends StatelessWidget {
  const StrokeText(
    this.text, {
    super.key,
    required this.style,
    this.strokeColor = AppColors.ink,
    this.strokeWidth = 4,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final Color strokeColor;
  final double strokeWidth;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        Text(text, textAlign: textAlign, style: style),
      ],
    );
  }
}
