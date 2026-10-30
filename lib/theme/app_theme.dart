import 'package:flutter/material.dart';

class AppThemeSpec {
  final String id;
  final String name;
  final String subtitle;
  final String emoji;
  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final List<Color> gradient;
  final bool glass;
  final double radius;

  const AppThemeSpec({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.gradient,
    this.glass = false,
    this.radius = 22,
  });

  bool get isDark => brightness == Brightness.dark;

  /// 渐变主视觉上的前景色：浅色主题用深色字，深色主题用白字。
  Color get onHero => isDark ? Colors.white : textPrimary;

  Color get onHeroMuted =>
      isDark ? Colors.white.withValues(alpha: .72) : textSecondary;

  LinearGradient get heroGradient => LinearGradient(
        colors: gradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  ThemeData toThemeData({bool transparentBackground = false}) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: _onColor(primary),
      secondary: secondary,
      onSecondary: _onColor(secondary),
      error: const Color(0xFFFF5A5F),
      onError: Colors.white,
      surface: transparentBackground ? Colors.transparent : surface,
      onSurface: textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          transparentBackground ? Colors.transparent : background,
      canvasColor: transparentBackground ? Colors.transparent : surface,
      cardColor: transparentBackground ? card.withValues(alpha: 0.82) : card,
      dividerColor: textPrimary.withValues(alpha: 0.08),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: textPrimary.withValues(alpha: 0.08)),
    );

    return base.copyWith(
      primaryColor: primary,
      appBarTheme: AppBarTheme(
        backgroundColor:
            transparentBackground ? Colors.transparent : background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: transparentBackground ? card.withValues(alpha: 0.82) : card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: textPrimary.withValues(alpha: 0.06)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: transparentBackground
            ? background.withValues(alpha: 0.94)
            : surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius + 4)),
        titleTextStyle: TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: TextStyle(color: textSecondary, height: 1.5),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: transparentBackground
            ? background.withValues(alpha: 0.97)
            : surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _onColor(primary),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _onColor(primary),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: textPrimary.withValues(alpha: 0.16)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: textPrimary.withValues(alpha: isDark ? 0.055 : 0.065),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF5A5F)),
        ),
        labelStyle: TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: isDark ? 0.65 : 0.8)),
        suffixStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: textPrimary, displayColor: textPrimary)
          .copyWith(
            bodyLarge:
                TextStyle(color: textPrimary, fontSize: 15, height: 1.55),
            bodyMedium:
                TextStyle(color: textSecondary, fontSize: 13.5, height: 1.55),
            titleLarge: TextStyle(
                color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
            titleMedium: TextStyle(
                color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            labelLarge: TextStyle(
                color: textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: textPrimary.withValues(alpha: 0.06),
        selectedColor: primary.withValues(alpha: 0.18),
        side: BorderSide(color: textPrimary.withValues(alpha: 0.06)),
        labelStyle: TextStyle(
            color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF252B36) : Colors.black87,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme:
          DividerThemeData(color: textPrimary.withValues(alpha: 0.07)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _onColor(primary);
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: primary,
        headerForegroundColor: _onColor(primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    );
  }

  static Color _onColor(Color color) {
    return color.computeLuminance() > .6
        ? const Color(0xFF101216)
        : Colors.white;
  }
}

enum AppThemeMode { light, system, dark }

class AppThemePalette {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final List<Color> gradient;

  const AppThemePalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.gradient,
  });
}

class AppThemeDefinition {
  final String id;
  final String name;
  final String subtitle;
  final String emoji;
  final AppThemePalette lightPalette;
  final AppThemePalette darkPalette;
  final bool glass;
  final double radius;

  const AppThemeDefinition({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.emoji,
    required this.lightPalette,
    required this.darkPalette,
    this.glass = false,
    this.radius = 22,
  });

  AppThemeSpec specFor({
    required AppThemeMode mode,
    required Brightness platformBrightness,
  }) {
    final useDark = mode == AppThemeMode.dark ||
        (mode == AppThemeMode.system && platformBrightness == Brightness.dark);
    return specForBrightness(
      useDark ? Brightness.dark : Brightness.light,
    );
  }

  AppThemeSpec specForBrightness(Brightness brightness) {
    final palette = brightness == Brightness.dark ? darkPalette : lightPalette;
    return AppThemeSpec(
      id: id,
      name: name,
      subtitle: subtitle,
      emoji: emoji,
      brightness: brightness,
      primary: palette.primary,
      secondary: palette.secondary,
      accent: palette.accent,
      background: palette.background,
      surface: palette.surface,
      card: palette.card,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      gradient: palette.gradient,
      glass: glass,
      radius: radius,
    );
  }
}

class AppThemes {
  static const ironForge = AppThemeDefinition(
    id: 'iron_forge',
    name: '黑金',
    subtitle: '铁馆灯光 · 力量与荣誉',
    emoji: '🏋️',
    lightPalette: AppThemePalette(
      primary: Color(0xFF8A5A12),
      secondary: Color(0xFFB4472F),
      accent: Color(0xFF0F766E),
      background: Color(0xFFF8F3E8),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF211A12),
      textSecondary: Color(0xFF66584A),
      gradient: [Color(0xFFF5E8CF), Color(0xFFFBF7EF), Color(0xFFE9D8B8)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFFE4B363),
      secondary: Color(0xFFE76F51),
      accent: Color(0xFF6EE7F9),
      background: Color(0xFF080B10),
      surface: Color(0xFF11161E),
      card: Color(0xFF151C26),
      textPrimary: Color(0xFFF4F1EA),
      textSecondary: Color(0xFF9BA7B7),
      gradient: [Color(0xFF1B2330), Color(0xFF0A0D13), Color(0xFF3B2B14)],
    ),
  );

  static const mountainMist = AppThemeDefinition(
    id: 'mountain_mist',
    name: '远山',
    subtitle: '青绿渐变 · 呼吸感留白',
    emoji: '⛰️',
    lightPalette: AppThemePalette(
      primary: Color(0xFF1F6F68),
      secondary: Color(0xFF2B6F86),
      accent: Color(0xFF2F7D5A),
      background: Color(0xFFF2FAF8),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF12211F),
      textSecondary: Color(0xFF4C625F),
      gradient: [Color(0xFFDDF3ED), Color(0xFFF8FCFB), Color(0xFFD9EAF5)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFF4FD1C5),
      secondary: Color(0xFF2E8B9E),
      accent: Color(0xFFA7F3D0),
      background: Color(0xFF0C1820),
      surface: Color(0xFF12222D),
      card: Color(0xFF172A36),
      textPrimary: Color(0xFFEEF7F7),
      textSecondary: Color(0xFF91A9B2),
      gradient: [Color(0xFF12313A), Color(0xFF0A171E), Color(0xFF1F4D4A)],
    ),
  );

  static const neonPulse = AppThemeDefinition(
    id: 'neon_pulse',
    name: '霓虹',
    subtitle: '紫青脉冲 · 未来训练舱',
    emoji: '⚡',
    lightPalette: AppThemePalette(
      primary: Color(0xFF6D28D9),
      secondary: Color(0xFF0E7490),
      accent: Color(0xFFBE185D),
      background: Color(0xFFF8F5FF),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF1B1530),
      textSecondary: Color(0xFF5B5470),
      gradient: [Color(0xFFEDE4FF), Color(0xFFFBF8FF), Color(0xFFDDF7FB)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFF22D3EE),
      accent: Color(0xFFF472B6),
      background: Color(0xFF080714),
      surface: Color(0xFF121026),
      card: Color(0xFF17142E),
      textPrimary: Color(0xFFF2F0FF),
      textSecondary: Color(0xFF9D97C4),
      gradient: [Color(0xFF241A52), Color(0xFF0B0918), Color(0xFF073B4C)],
    ),
  );

  static const sunset = AppThemeDefinition(
    id: 'sunset',
    name: '落日',
    subtitle: '橙红渐变 · 热血燃烧',
    emoji: '🌇',
    lightPalette: AppThemePalette(
      primary: Color(0xFFB9430C),
      secondary: Color(0xFFB91C1C),
      accent: Color(0xFF9A6700),
      background: Color(0xFFFFF7EF),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF2A160D),
      textSecondary: Color(0xFF6B4A3A),
      gradient: [Color(0xFFFFE1BE), Color(0xFFFFF9F2), Color(0xFFFFD3C2)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFFFFA24C),
      secondary: Color(0xFFFF5E5B),
      accent: Color(0xFFFFD166),
      background: Color(0xFF140D0A),
      surface: Color(0xFF211511),
      card: Color(0xFF2A1A14),
      textPrimary: Color(0xFFFFF6EC),
      textSecondary: Color(0xFFC0A394),
      gradient: [Color(0xFF4A1F14), Color(0xFF160D09), Color(0xFF7A3517)],
    ),
  );

  static const forest = AppThemeDefinition(
    id: 'forest',
    name: '森野',
    subtitle: '苔绿木质 · 自然恢复力',
    emoji: '🌿',
    lightPalette: AppThemePalette(
      primary: Color(0xFF3F6212),
      secondary: Color(0xFF7A5230),
      accent: Color(0xFF8A5A00),
      background: Color(0xFFF6FAF1),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF17200F),
      textSecondary: Color(0xFF536044),
      gradient: [Color(0xFFE4F0D7), Color(0xFFFBFDF7), Color(0xFFF1E7D5)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFF7BAA6E),
      secondary: Color(0xFFB08968),
      accent: Color(0xFFE9C46A),
      background: Color(0xFF0D1410),
      surface: Color(0xFF152019),
      card: Color(0xFF1A2A21),
      textPrimary: Color(0xFFF0F5EB),
      textSecondary: Color(0xFFA1B5A5),
      gradient: [Color(0xFF1C3326), Color(0xFF0B120E), Color(0xFF3A2E1F)],
    ),
  );

  static const midnightGlass = AppThemeDefinition(
    id: 'midnight_glass',
    name: '琉璃',
    subtitle: '半透明玻璃 · 沉浸式光影',
    emoji: '🫧',
    lightPalette: AppThemePalette(
      primary: Color(0xFF0369A1),
      secondary: Color(0xFF6D28D9),
      accent: Color(0xFFBE185D),
      background: Color(0xFFF5FAFF),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF10202E),
      textSecondary: Color(0xFF4B5E6E),
      gradient: [Color(0xFFDDF1FF), Color(0xFFFBFDFF), Color(0xFFEEE8FF)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFF7DD3FC),
      secondary: Color(0xFFC4B5FD),
      accent: Color(0xFFF9A8D4),
      background: Color(0xFF070B12),
      surface: Color(0xFF0E1520),
      card: Color(0xFF101A27),
      textPrimary: Color(0xFFF3F8FF),
      textSecondary: Color(0xFF93A4B8),
      gradient: [Color(0xFF14293D), Color(0xFF070B12), Color(0xFF2A1638)],
    ),
    glass: true,
  );

  static const sakura = AppThemeDefinition(
    id: 'sakura',
    name: '樱雾',
    subtitle: '奶油粉白 · 温柔但有力量',
    emoji: '🌸',
    lightPalette: AppThemePalette(
      primary: Color(0xFFB44B6E),
      secondary: Color(0xFF7657BF),
      accent: Color(0xFF16867C),
      background: Color(0xFFFFF7F8),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF241C22),
      textSecondary: Color(0xFF4E4148),
      gradient: [Color(0xFFFFE4EC), Color(0xFFFFF8FA), Color(0xFFEDE7FF)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFFD97A9B),
      secondary: Color(0xFFA78BFA),
      accent: Color(0xFF2DD4BF),
      background: Color(0xFF1A1115),
      surface: Color(0xFF241820),
      card: Color(0xFF2B1D26),
      textPrimary: Color(0xFFFFF2F6),
      textSecondary: Color(0xFFC7AAB5),
      gradient: [Color(0xFF3A202B), Color(0xFF1A1115), Color(0xFF2B2140)],
    ),
  );

  static const porcelain = AppThemeDefinition(
    id: 'porcelain',
    name: '珠玉',
    subtitle: '汉白玉渐变 · 温润护眼',
    emoji: '🤍',
    lightPalette: AppThemePalette(
      primary: Color(0xFF315A8F),
      secondary: Color(0xFF4E6FA3),
      accent: Color(0xFF9B6420),
      background: Color(0xFFF5F6F8),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF171E27),
      textSecondary: Color(0xFF3F4A5A),
      gradient: [Color(0xFFFDFBF7), Color(0xFFF1F4F9), Color(0xFFE4EDF9)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFF6F97C8),
      secondary: Color(0xFF7FA3C9),
      accent: Color(0xFFD6A45E),
      background: Color(0xFF0E131A),
      surface: Color(0xFF151C25),
      card: Color(0xFF19222D),
      textPrimary: Color(0xFFF1F6FC),
      textSecondary: Color(0xFF9FB0C2),
      gradient: [Color(0xFF1B2A3D), Color(0xFF0E131A), Color(0xFF233247)],
    ),
  );

  static const materialYou = AppThemeDefinition(
    id: 'material_you',
    name: '莫奈',
    subtitle: 'Material 3 · 开源调色板',
    emoji: '🎨',
    lightPalette: AppThemePalette(
      primary: Color(0xFF2A574A),
      secondary: Color(0xFF5C7350),
      accent: Color(0xFF8A5738),
      background: Color(0xFFF7FBF7),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF141715),
      textSecondary: Color(0xFF37423B),
      gradient: [Color(0xFFDCEFE6), Color(0xFFFDFBF4), Color(0xFFE8E3F7)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFF5FA88C),
      secondary: Color(0xFF91B37E),
      accent: Color(0xFFC58F66),
      background: Color(0xFF0C1411),
      surface: Color(0xFF121C18),
      card: Color(0xFF16221D),
      textPrimary: Color(0xFFEFF7F2),
      textSecondary: Color(0xFFA1B5AA),
      gradient: [Color(0xFF1B332A), Color(0xFF0C1411), Color(0xFF2B2438)],
    ),
  );

  static const inkPupil = AppThemeDefinition(
    id: 'ink_pupil',
    name: '墨瞳',
    subtitle: '墨色瞳孔 · 极简黑白',
    emoji: '🌑',
    lightPalette: AppThemePalette(
      primary: Color(0xFF1F2937),
      secondary: Color(0xFF6B7280),
      accent: Color(0xFFB91C1C),
      background: Color(0xFFF7F7F5),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF111111),
      textSecondary: Color(0xFF555555),
      gradient: [Color(0xFFECECEA), Color(0xFFFAFAF8), Color(0xFFDCDCDC)],
    ),
    darkPalette: AppThemePalette(
      primary: Color(0xFFE5E7EB),
      secondary: Color(0xFF9CA3AF),
      accent: Color(0xFFEF4444),
      background: Color(0xFF050505),
      surface: Color(0xFF0D0D0D),
      card: Color(0xFF121212),
      textPrimary: Color(0xFFF5F5F5),
      textSecondary: Color(0xFF9CA3AF),
      gradient: [Color(0xFF1A1A1A), Color(0xFF050505), Color(0xFF222222)],
    ),
  );

  static const List<AppThemeDefinition> all = [
    ironForge,
    mountainMist,
    neonPulse,
    sunset,
    forest,
    midnightGlass,
    sakura,
    porcelain,
    materialYou,
    inkPupil,
  ];

  static AppThemeDefinition byId(String? id) {
    return all.firstWhere(
      (theme) => theme.id == id,
      orElse: () => ironForge,
    );
  }
}
