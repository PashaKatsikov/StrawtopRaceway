import 'package:flutter_test/flutter_test.dart';

import 'package:strawtop_raceway/data/catalog.dart';

void main() {
  test('catalog builds levels for every location', () {
    expect(Catalog.levels.isNotEmpty, true);
    for (final loc in Catalog.locations) {
      expect(Catalog.levelsFor(loc.id).length, loc.levelCount);
    }
  });

  test('first top is free and starter-owned', () {
    expect(Catalog.tops.first.price, 0);
  });
}
