import 'package:bellenissimos_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final light = recipeBoxLight.extension<BoxTokens>()!;
  final dark = recipeBoxDark.extension<BoxTokens>()!;

  test('copyWith replaces only the given tokens', () {
    const accent = Color(0xFF123456);
    final edited = dark.copyWith(accent: accent);

    expect(edited.accent, accent);
    expect(edited.ground, dark.ground);
    expect(edited.card, dark.card);
    expect(edited.onCard, dark.onCard);
    expect(edited.rule, dark.rule);
    expect(edited.pencil, dark.pencil);
    expect(edited.annotation, dark.annotation);
    expect(dark.accent, const Color(0xFFE06A55));

    const ground = Color(0xFF654321);
    final reGrounded = dark.copyWith(ground: ground);
    expect(reGrounded.ground, ground);
    expect(reGrounded.accent, dark.accent);
  });

  test('lerp mixes every token at t=0.5', () {
    final mid = light.lerp(dark, 0.5);

    expect(mid.ground,
        Color.lerp(const Color(0xFF3E2F23), const Color(0xFF241B14), 0.5));
    expect(mid.accent,
        Color.lerp(const Color(0xFFC03B2E), const Color(0xFFE06A55), 0.5));
    expect(mid.ground, isNot(light.ground));
    expect(mid.ground, isNot(dark.ground));
    expect(light.lerp(dark, 1.0).ground, dark.ground);
    expect(light.lerp(null, 0.5), same(light));
  });
}
