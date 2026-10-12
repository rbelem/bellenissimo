import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Pan area and volume', () {
    test('round pan area is pi r squared', () {
      expect(Pan.round(20, 5).areaCm2, closeTo(314.16, 0.01));
    });

    test('square pan area is side squared', () {
      expect(Pan.square(20, 5).areaCm2, 400);
    });

    test('rectangular pan area is length times width', () {
      expect(Pan.rectangular(30, 20, 5).areaCm2, 600);
    });

    test('volume is area times depth', () {
      expect(Pan.round(20, 5).volumeMl, closeTo(314.16 * 5, 0.1));
      expect(Pan.square(20, 5).volumeMl, 2000);
      expect(Pan.rectangular(30, 20, 5).volumeMl, 3000);
    });
  });

  group('panScaleFactor', () {
    test('follows area for equal depths', () {
      final factor = panScaleFactor(Pan.round(20, 5), Pan.round(24, 5));
      expect(factor, closeTo(1.44, 0.0001));
    });

    test('follows volume, not area', () {
      // Same area (400 cm²), double the depth: double the volume.
      final factor = panScaleFactor(Pan.square(20, 3), Pan.square(20, 6));
      expect(factor, 2);
    });
  });

  group('scaledBakingTime', () {
    test('scales by factor^0.8, rounded to whole minutes', () {
      // 40 × 1.44^0.8 ≈ 53.55 → 54 minutes.
      expect(
        scaledBakingTime(const Duration(minutes: 40), 1.44),
        const Duration(minutes: 54),
      );
    });

    test('never more than double the base', () {
      expect(
        scaledBakingTime(const Duration(minutes: 40), 4),
        const Duration(minutes: 80),
      );
    });

    test('never less than half the base', () {
      expect(
        scaledBakingTime(const Duration(minutes: 40), 0.1),
        const Duration(minutes: 20),
      );
    });
  });

  group('Pan validation', () {
    test('rejects zero and negative round dimensions', () {
      expect(() => Pan.round(0, 5), throwsArgumentError);
      expect(() => Pan.round(-20, 5), throwsArgumentError);
      expect(() => Pan.round(20, 0), throwsArgumentError);
    });

    test('rejects zero and negative square dimensions', () {
      expect(() => Pan.square(0, 5), throwsArgumentError);
      expect(() => Pan.square(-20, 5), throwsArgumentError);
      expect(() => Pan.square(20, 0), throwsArgumentError);
    });

    test('rejects zero and negative rectangular dimensions', () {
      expect(() => Pan.rectangular(0, 20, 5), throwsArgumentError);
      expect(() => Pan.rectangular(30, -20, 5), throwsArgumentError);
      expect(() => Pan.rectangular(30, 20, 0), throwsArgumentError);
    });
  });
}
