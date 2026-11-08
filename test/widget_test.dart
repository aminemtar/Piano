import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:piano/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the piano learning home screen', (tester) async {
    await tester.pumpWidget(const PianoLearnApp());
    await tester.pumpAndSettle();

    expect(find.text('piano.'), findsOneWidget);
    expect(find.text('Your piano'), findsOneWidget);
    expect(find.text('Do'), findsWidgets);
    expect(find.text('Practice'), findsOneWidget);
  });
}
