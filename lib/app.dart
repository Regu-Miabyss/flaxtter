import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flaxtter/features/home/home_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_fonts.dart';
import 'package:flaxtter/utils/scroll_behavior.dart';
import 'package:flaxtter/widgets/blank_area_mouse_scroll.dart';

const _fontFamily = 'GoogleSansFlex';
const _twitterBlue = Color(0xFF1DA1F2);

ColorScheme _fallbackScheme(Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: _twitterBlue,
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

  ThemeData _theme(ColorScheme colorScheme) {
    final layered = _layeredColorScheme(colorScheme);
    final base = ThemeData(
      colorScheme: layered,
      useMaterial3: true,
      fontFamily: _fontFamily,
      fontFamilyFallback: emojiFontFamilyFallback,
      scaffoldBackgroundColor: layered.surfaceContainerLowest,
    );
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: layered.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
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
      dividerTheme: DividerThemeData(
        color: layered.outlineVariant.withValues(alpha: 0.35),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: _fontFamily,
        fontFamilyFallback: emojiFontFamilyFallback,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: _fontFamily,
        fontFamilyFallback: emojiFontFamilyFallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = lightDynamic ?? _fallbackScheme(Brightness.light);
        final darkScheme = darkDynamic ?? _fallbackScheme(Brightness.dark);

        return MaterialApp(
          scrollBehavior: const FlaxtterScrollBehavior(),
          builder: (context, child) {
            final theme = Theme.of(context);
            return BlankAreaMouseDragScroll(
              child: ScrollConfiguration(
                behavior: const FlaxtterScrollBehavior(),
                child: DefaultTextStyle(
                  style: withEmojiFontFallback(theme.textTheme.bodyMedium ?? const TextStyle()),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          locale: const Locale('zh', 'TW'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _theme(lightScheme),
          darkTheme: _theme(darkScheme),
          routes: {
            '/gate': (_) => const AuthGate(),
          },
          home: const AuthGate(),
        );
      },
    );
  }
}
