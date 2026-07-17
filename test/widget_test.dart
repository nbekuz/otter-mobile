import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/theme/otter_colors.dart';

void main() {
  test('Otter brand colors match design tokens', () {
    expect(OtterColors.sberGreen.toARGB32(), 0xFF21A038);
    expect(OtterColors.sberBlue.toARGB32(), 0xFF007AFF);
  });
}
