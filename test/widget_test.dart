import 'package:flutter_test/flutter_test.dart';
import 'package:delhi_aqi/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const DelhiAqiApp());
    expect(find.text('Delhi AQI'), findsOneWidget);
  });
}