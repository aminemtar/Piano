import 'package:flutter/widgets.dart';
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
    expect(find.text('Piano'), findsOneWidget);
    expect(find.text('Darbuka'), findsOneWidget);
    expect(find.text('Your piano'), findsOneWidget);
    expect(find.text('Do'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Practice'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Practice'), findsOneWidget);
  });
  test('song catalog stays inside the two-octave keyboard', () {
    expect(songs, hasLength(12));
    for (final song in songs) {
      expect(song.notes, isNotEmpty, reason: song.title);
      expect(song.bpm, greaterThan(0), reason: song.title);
      expect(
        song.notes.every((midi) => midi >= 60 && midi <= 83),
        isTrue,
        reason: '${song.title} contains a note outside C4–B5',
      );
    }
  });

  test('keyboard note labels include both octave boundaries', () {
    expect(noteLabel(60), 'C4');
    expect(noteLabel(83), 'B5');
  });

  testWidgets('opens the playable darbuka instrument', (tester) async {
    await tester.pumpWidget(const PianoLearnApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Darbuka'));
    await tester.pumpAndSettle();

    expect(find.text('Darbuka lessons'), findsOneWidget);
    expect(find.text('TEMPO & METRONOME'), findsOneWidget);
    expect(find.text('DOUM'), findsWidgets);
    expect(find.text('TEK'), findsWidgets);
    expect(find.text('KA'), findsWidgets);
    expect(find.text('PRACTICE ON THE DRUM'), findsOneWidget);
  });


}
