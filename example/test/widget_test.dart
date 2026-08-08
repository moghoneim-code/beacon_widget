import 'package:assist/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('widget matrix renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const BeaconTestApp());
    expect(find.text('Beacon Widget Matrix'), findsOneWidget);
    expect(find.text('Custom widget (BeaconCard)'), findsOneWidget);
  });
}
