import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/theme/otter_colors.dart';

void main() {
  test('Otter brand colors match design tokens', () {
    expect(OtterColors.sberGreen.value, 0xFF21A038);
    expect(OtterColors.sberBlue.value, 0xFF007AFF);
  });
}
