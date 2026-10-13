import 'package:flutter/material.dart';

/// Recipe Box world tokens (direction contract, seed 6b8aa06f).
class BoxTokens extends ThemeExtension<BoxTokens> {
  const BoxTokens({
    required this.ground,
    required this.card,
    required this.onCard,
    required this.rule,
    required this.accent,
    required this.pencil,
    required this.annotation,
  });

  final Color ground;
  final Color card;
  final Color onCard;
  final Color rule;
  final Color accent;
  final Color pencil;
  final Color annotation;

  @override
  BoxTokens copyWith({
    Color? ground,
    Color? card,
    Color? onCard,
    Color? rule,
    Color? accent,
    Color? pencil,
    Color? annotation,
  }) => BoxTokens(
    ground: ground ?? this.ground,
    card: card ?? this.card,
    onCard: onCard ?? this.onCard,
    rule: rule ?? this.rule,
    accent: accent ?? this.accent,
    pencil: pencil ?? this.pencil,
    annotation: annotation ?? this.annotation,
  );

  @override
  BoxTokens lerp(BoxTokens? other, double t) {
    if (other == null) return this;
    return BoxTokens(
      ground: Color.lerp(ground, other.ground, t)!,
      card: Color.lerp(card, other.card, t)!,
      onCard: Color.lerp(onCard, other.onCard, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      pencil: Color.lerp(pencil, other.pencil, t)!,
      annotation: Color.lerp(annotation, other.annotation, t)!,
    );
  }
}

const _stampRed = Color(0xFFC03B2E);

const BoxTokens _lightTokens = BoxTokens(
  ground: Color(0xFF3E2F23),
  card: Color(0xFFF7F2E9),
  onCard: Color(0xFF2B2118),
  rule: Color(0xFFE2D8C4),
  accent: _stampRed,
  pencil: Color(0xFF6E6252),
  annotation: Color(0xFF6E6252),
);

const BoxTokens _darkTokens = BoxTokens(
  ground: Color(0xFF241B14),
  card: Color(0xFF35291E),
  onCard: Color(0xFFF1E9DA),
  rule: Color(0xFF4A3B2C),
  accent: Color(0xFFE06A55),
  pencil: Color(0xFFB3A48D),
  annotation: Color(0xFFB3A48D),
);

const _titleFamily = 'ZillaSlab';
const _quantityFamily = 'CourierPrime';
const _annotationFamily = 'Caveat';

/// Title voice for card and lid headings.
TextStyle boxTitle(BuildContext context, {double size = 19}) => TextStyle(
  fontFamily: _titleFamily,
  fontWeight: FontWeight.w600,
  fontSize: size,
  color: Theme.of(context).extension<BoxTokens>()!.onCard,
);

/// Measurement voice: every quantity and every numeral.
TextStyle boxQuantity(BuildContext context, {double size = 14.5}) => TextStyle(
  fontFamily: _quantityFamily,
  fontSize: size,
  color: Theme.of(context).extension<BoxTokens>()!.onCard,
);

/// Lineage voice: pencil notes about family relations.
TextStyle boxAnnotation(BuildContext context, {double size = 17}) => TextStyle(
  fontFamily: _annotationFamily,
  fontWeight: FontWeight.w400,
  fontSize: size,
  color: Theme.of(context).extension<BoxTokens>()!.annotation,
  height: 1.25,
);

/// Rubber-stamp voice: the VARIANT mark and nothing else.
TextStyle boxStamp(BuildContext context) => TextStyle(
  fontFamily: _titleFamily,
  fontWeight: FontWeight.w600,
  fontSize: 11,
  letterSpacing: 2,
  color: Theme.of(context).extension<BoxTokens>()!.accent,
);

ThemeData _boxTheme(Brightness brightness, BoxTokens tokens) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.accent,
    onPrimary: tokens.card,
    secondary: tokens.accent,
    onSecondary: tokens.card,
    error: tokens.accent,
    onError: tokens.card,
    surface: tokens.ground,
    onSurface: brightness == Brightness.light
        ? const Color(0xFFF7F2E9)
        : const Color(0xFFF1E9DA),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.ground,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.ground,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _titleFamily,
        fontWeight: FontWeight.w600,
        fontSize: 21,
        color: scheme.onSurface,
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: tokens.accent,
      inactiveTrackColor: brightness == Brightness.light
          ? const Color(0xFFE2D8C4)
          : const Color(0xFF4A3B2C),
      thumbColor: tokens.accent,
      overlayColor: tokens.accent.withValues(alpha: 0.15),
      trackShape: const RoundedRectSliderTrackShape(),
    ),
    textTheme: Typography.material2021().black.apply(
      bodyColor: tokens.onCard,
      displayColor: tokens.onCard,
    ),
  );
}

final ThemeData recipeBoxLight = _boxTheme(Brightness.light, _lightTokens);

final ThemeData recipeBoxDark = _boxTheme(Brightness.dark, _darkTokens);
