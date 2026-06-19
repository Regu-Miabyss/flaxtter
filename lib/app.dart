import 'package:flaxtter/widgets/desktop_color_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flaxtter/features/home/home_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_fonts.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/scroll_behavior.dart';
import 'package:flaxtter/widgets/blank_area_mouse_scroll.dart';
import 'package:provider/provider.dart';

const _fontFamily = 'GoogleSansFlex';

ColorScheme _seedScheme(int seedColor, Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: Color(seedColor),
    brightness: brightness,
  );
}

/// Ensures page background and elevated surfaces (cards, bars) stay visually distinct.
ColorScheme _layeredColorScheme(ColorScheme scheme) {
  final isLight = scheme.brightness == Brightness.light;
  final pageBackground = scheme.surfaceContainerLowest;
  var cardSurface = isLight ? scheme.surfaceContainerLow : scheme.surfaceContainerHigh;

  // Some dynamic palettes collapse container levels — force a subtle lift for cards.
  if (pageBackground.toARGB32() == cardSurface.toARGB32() ||
      scheme.surface.toARGB32() == pageBackground.toARGB32()) {
    cardSurface = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: isLight ? 0.06 : 0.12),
      pageBackground,
    );
  }

  return scheme.copyWith(
    surface: cardSurface,
    surfaceContainerLowest: pageBackground,
    surfaceContainerLow: isLight ? cardSurface : scheme.surfaceContainerLow,
    surfaceContainerHigh: isLight ? scheme.surfaceContainerHigh : cardSurface,
  );
}

class FlaxtterApp extends StatelessWidget {
  const FlaxtterApp({super.key});

  ThemeData _theme(
    ColorScheme colorScheme,
    String fontFamily,
    List<String> fontFallback,
    double textScale,
  ) {
    final layered = _layeredColorScheme(colorScheme);
    final base = ThemeData(
      colorScheme: layered,
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: layered.surfaceContainerLowest,
    );
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: layered.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        // Icons must not follow text scaling — scaled back chevrons clip to a slash.
        iconTheme: const IconThemeData(size: 24),
        actionsIconTheme: const IconThemeData(size: 24),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: layered.surfaceContainerLow,
        indicatorColor: layered.secondaryContainer,
      ),
      cardTheme: CardThemeData(
        color: layered.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: layered.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        indicatorColor: layered.primary,
        labelColor: layered.onSurface,
        unselectedLabelColor: layered.onSurfaceVariant,
        dividerColor: layered.outlineVariant.withValues(alpha: 0.45),
      ),
      dividerTheme: DividerThemeData(
        color: layered.outlineVariant.withValues(alpha: 0.35),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSizeFactor: textScale,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSizeFactor: textScale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    final fontFamily = settings.customFontFamily ?? _fontFamily;
    final fontFallback = fontFamilyFallbackFor(settings.locale);
    // Keep the bundled font (and CJK / emoji) as fallback behind a custom font.
    final effectiveFallback = settings.customFontFamily != null
        ? [_fontFamily, ...fontFallback]
        : fontFallback;

    return DesktopColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final useDynamic = settings.useDynamicColor;
        final lightScheme = useDynamic && lightDynamic != null
            ? lightDynamic
            : _seedScheme(settings.seedColor, Brightness.light);
        final darkScheme = useDynamic && darkDynamic != null
            ? darkDynamic
            : _seedScheme(settings.seedColor, Brightness.dark);

        return MaterialApp(
          scrollBehavior: const FlaxtterScrollBehavior(),
          builder: (context, child) {
            final theme = Theme.of(context);
            final settings = context.watch<AppSettings>();
            return BlankAreaMouseDragScroll(
              child: ScrollConfiguration(
                behavior: const FlaxtterScrollBehavior(),
                child: DefaultTextStyle(
                  style: withEmojiFontFallback(
                    theme.textTheme.bodyMedium ?? const TextStyle(),
                    settings.locale,
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _theme(lightScheme, fontFamily, effectiveFallback, settings.textScale),
          darkTheme: _theme(darkScheme, fontFamily, effectiveFallback, settings.textScale),
          themeMode: settings.themeMode,
          routes: {
            '/gate': (_) => const AuthGate(),
          },
          home: const AuthGate(),
        );
      },
    );
  }
}
