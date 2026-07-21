import 'package:flutter/material.dart';

/// Central design system for Strawtop Raceway.
/// A premium "sunset stadium" cartoon look: a deep indigo→plum backdrop washed
/// with a warm golden glow, glassy gradient cards with inner sheen, thick
/// outlines, vibrant candy accents, layered soft shadows and coloured glows.
class AppColors {
  // Base backdrop tones (indigo → plum → near-black).
  static const Color navyDeep = Color(0xFF0B0E2A);
  static const Color navy = Color(0xFF221A55);
  static const Color navyLight = Color(0xFF3A2A7A);

  // Surfaces (slightly violet, glassy).
  static const Color panel = Color(0xFF272254);
  static const Color panelLight = Color(0xFF3A3577);

  // Accents.
  static const Color red = Color(0xFFFF5470);
  static const Color redDark = Color(0xFFD32F4E);
  static const Color yellow = Color(0xFFFFD23F);
  static const Color yellowDark = Color(0xFFF5A623);
  static const Color blue = Color(0xFF35B8F1);
  static const Color blueDark = Color(0xFF1E7FC2);
  static const Color green = Color(0xFF3DDC84);
  static const Color greenDark = Color(0xFF1FA65A);
  static const Color purple = Color(0xFFA974FF);
  static const Color purpleDark = Color(0xFF7A45D9);
  static const Color pink = Color(0xFFFF6EC7);
  static const Color cyan = Color(0xFF43E5D0);

  // Warm glow used to light the top of the screen.
  static const Color glow = Color(0xFFFF9D5C);

  static const Color ink = Color(0xFF080A22);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFB3AEE0);

  // Frosted card edge / highlight.
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassHi = Color(0x40FFFFFF);

  // ---- Backdrop -----------------------------------------------------------
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyLight, navy, navyDeep],
    stops: [0.0, 0.5, 1.0],
  );

  /// Warm radial glow layered on top of [bgGradient] for depth.
  static const RadialGradient bgGlow = RadialGradient(
    center: Alignment(0, -0.85),
    radius: 1.2,
    colors: [Color(0x55FF9D5C), Color(0x00FF9D5C)],
  );

  /// Soft dark vignette for the screen edges.
  static const RadialGradient vignette = RadialGradient(
    center: Alignment.center,
    radius: 1.1,
    colors: [Color(0x00000000), Color(0x66000000)],
    stops: [0.65, 1.0],
  );

  // ---- Surface gradients (glassy) -----------------------------------------
  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A3577), Color(0xFF231F4C)],
  );

  // ---- Button / accent gradients ------------------------------------------
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE066), yellow, yellowDark],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5CF09B), green, greenDark],
  );

  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A8E), red, redDark],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF63CDF7), blue, blueDark],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC49CFF), purple, purpleDark],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pink, Color(0xFFFF8A5C), yellow],
  );
}

class AppRadius {
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;
}

/// Reusable shadow / glow presets.
class AppShadow {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> glow(Color c, {double strength = 0.5}) => [
        BoxShadow(
          color: c.withValues(alpha: strength),
          blurRadius: 22,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ];
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

/// Outlined text whose fill is a gradient – used for hero titles.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.gradient,
    this.strokeColor = AppColors.ink,
    this.strokeWidth = 5,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final Gradient gradient;
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
        ShaderMask(
          shaderCallback: (rect) => gradient.createShader(rect),
          child: Text(text,
              textAlign: textAlign,
              style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
