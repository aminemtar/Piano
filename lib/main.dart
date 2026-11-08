import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const PianoLearnApp());

const navy = Color(0xFF101B36);
const cobalt = Color(0xFF315BFF);
const cyan = Color(0xFF54D8F2);
const paper = Color(0xFFF4F7FF);

class PianoLearnApp extends StatelessWidget {
  const PianoLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(seedColor: cobalt, brightness: Brightness.light),
        fontFamily: 'Roboto',
      ),
      home: const PianoHomePage(),
    );
  }
}

class PianoNote {
  final int midi;
  final String name;
  final String solfege;
  const PianoNote(this.midi, this.name, this.solfege);
}

const noteNames = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
const solfege = ['Do', 'Do♯', 'Re', 'Re♯', 'Mi', 'Fa', 'Fa♯', 'Sol', 'Sol♯', 'La', 'La♯', 'Si'];

String noteLabel(int midi) => '${noteNames[midi % 12]}${(midi ~/ 12) - 1}';
String solfegeLabel(int midi) => solfege[midi % 12];

class Song {
  final String title;
  final String subtitle;
  final String level;
  final int bpm;
  final List<int> notes;
  const Song(this.title, this.subtitle, this.level, this.bpm, this.notes);
}

const songs = [
  Song('Ode to Joy', 'Beethoven · Theme', 'Beginner', 92,
      [64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 64, 62, 62]),
  Song('Twinkle, Twinkle', 'Traditional melody', 'Beginner', 84,
      [60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60]),
  Song('Mary Had a Little Lamb', 'Traditional melody', 'Beginner', 96,
      [64, 62, 60, 62, 64, 64, 64, 62, 62, 62, 64, 67, 67]),
];

class PianoHomePage extends StatefulWidget {
  const PianoHomePage({super.key});

  @override
  State<PianoHomePage> createState() => _PianoHomePageState();
}

class _PianoHomePageState extends State<PianoHomePage> {
  int selectedTab = 0;
  int songIndex = 0;
  int activeMidi = -1;
  int targetIndex = 0;
  int completedSongs = 0;
  int xp = 0;
  int streak = 1;
  String mode = 'idle';
  bool isPlayingDemo = false;
  String feedback = 'Choose a song and start learning';
  final Map<int, AudioPlayer> _players = {};
  Timer? _demoTimer;
  Timer? _flashTimer;
  SharedPreferences? _prefs;

  Song get song => songs[songIndex];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      xp = _prefs?.getInt('xp') ?? 0;
      completedSongs = _prefs?.getInt('completed') ?? 0;
      streak = _prefs?.getInt('streak') ?? 1;
    });
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _flashTimer?.cancel();
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  Uint8List _makeTone(int midi, {int durationMs = 420}) {
    const sampleRate = 22050;
    final count = sampleRate * durationMs ~/ 1000;
    final frequency = 440 * math.pow(2, (midi - 69) / 12);
    final data = ByteData(44 + count * 2);
    void writeText(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }
    writeText(0, 'RIFF');
    data.setUint32(4, 36 + count * 2, Endian.little);
    writeText(8, 'WAVE');
    writeText(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeText(36, 'data');
    data.setUint32(40, count * 2, Endian.little);
    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      final attack = math.min(1.0, i / (sampleRate * 0.012));
      final decay = math.exp(-3.8 * t);
      final fundamental = math.sin(2 * math.pi * frequency * t);
      final harmonic2 = math.sin(2 * math.pi * frequency * 2 * t) * 0.28;
      final harmonic3 = math.sin(2 * math.pi * frequency * 3 * t) * 0.10;
      final sample = ((fundamental + harmonic2 + harmonic3) * attack * decay * 0.58)
          .clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  Future<void> _playNote(int midi) async {
    try {
      final old = _players.remove(midi);
      if (old != null) await old.dispose();
      final player = AudioPlayer();
      _players[midi] = player;
      await player.play(BytesSource(_makeTone(midi)));
      player.onPlayerComplete.listen((_) {
        if (identical(_players[midi], player)) _players.remove(midi);
        player.dispose();
      });
    } catch (_) {
      if (mounted) setState(() => feedback = 'Audio could not start. Please try again.');
    }
  }

  void _pressKey(int midi) {
    _playNote(midi);
    setState(() => activeMidi = midi);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => activeMidi = -1);
    });
    if (mode == 'practice' || mode == 'challenge') {
      _checkAnswer(midi);
    }
  }

  void _checkAnswer(int midi) {
    if (targetIndex >= song.notes.length) return;
    final expected = song.notes[targetIndex];
    if (midi == expected) {
      setState(() {
        targetIndex++;
        xp += 5;
        feedback = targetIndex == song.notes.length
            ? 'Beautiful! You played the whole melody.'
            : 'Correct! ${targetIndex} of ${song.notes.length} notes';
      });
      _prefs?.setInt('xp', xp);
      if (targetIndex == song.notes.length) _finishSong();
    } else {
      setState(() => feedback = 'Not quite — try ${noteLabel(expected)} (${solfegeLabel(expected)})');
      if (mode == 'practice') {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && mode == 'practice') _playNote(expected);
        });
      }
    }
  }

  void _finishSong() {
    _demoTimer?.cancel();
    setState(() {
      mode = 'complete';
      completedSongs = math.max(completedSongs, songIndex + 1).toInt();
      feedback = 'Song completed! You earned ${song.notes.length * 5} XP.';
    });
    _prefs?.setInt('completed', completedSongs);
    _prefs?.setInt('xp', xp);
  }

  Future<void> _playDemo() async {
    _demoTimer?.cancel();
    setState(() {
      mode = 'watch';
      isPlayingDemo = true;
      feedback = 'Listen and watch the highlighted keys';
      activeMidi = -1;
    });
    var i = 0;
    final interval = Duration(milliseconds: (60000 / song.bpm).round());
    Future<void> tick() async {
      if (!mounted || i >= song.notes.length) {
        if (mounted) setState(() {
          isPlayingDemo = false;
          activeMidi = -1;
          feedback = 'Your turn — play the melody yourself';
          mode = 'ready';
        });
        return;
      }
      final midi = song.notes[i++];
      setState(() => activeMidi = midi);
      await _playNote(midi);
      _demoTimer = Timer(interval, tick);
    }
    await tick();
  }

  void _startPractice({bool challenge = false}) {
    _demoTimer?.cancel();
    setState(() {
      mode = challenge ? 'challenge' : 'practice';
      targetIndex = 0;
      feedback = challenge ? 'Play the song from memory. You can do it!' : 'Follow the notes. The first note is ${noteLabel(song.notes.first)}';
    });
    if (!challenge) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && mode == 'practice') _playNote(song.notes.first);
      });
    }
  }

  void _resetPractice() {
    setState(() {
      targetIndex = 0;
      mode = 'ready';
      feedback = 'Ready to try again?';
    });
  }

  Future<void> _openFullScreenPiano() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FullScreenPianoPage(
        onKeyPressed: _pressKey,
        songTitle: song.title,
      ),
    ));
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _selectSong(int index) {
    _demoTimer?.cancel();
    setState(() {
      songIndex = index;
      targetIndex = 0;
      mode = 'idle';
      isPlayingDemo = false;
      activeMidi = -1;
      feedback = 'New song selected. Start with a demonstration.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: selectedTab == 0 ? _learnPage() : selectedTab == 1 ? _libraryPage() : _progressPage(),
            ),
            _bottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    child: Row(
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [cobalt, Color(0xFF6E8BFF)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: cobalt.withOpacity(.22), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 11),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('piano.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy, letterSpacing: -.7)),
          Text('YOUR MUSIC JOURNEY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF8490AA), letterSpacing: 1.5)),
        ]),
        const Spacer(),
        _statPill(Icons.bolt_rounded, '$xp XP', const Color(0xFFFFA928)),
        const SizedBox(width: 8),
        _statPill(Icons.local_fire_department_rounded, '$streak', const Color(0xFFFF765E)),
      ],
    ),
  );

  Widget _statPill(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFE8ECF5))),
    child: Row(children: [Icon(icon, size: 15, color: color), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy))]),
  );

  Widget _learnPage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
    children: [
      _welcomeCard(),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Continue learning', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
        TextButton(onPressed: () => setState(() => selectedTab = 1), child: const Text('All songs')),
      ]),
      _songCard(),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Your piano', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
        TextButton.icon(
          onPressed: _openFullScreenPiano,
          icon: const Icon(Icons.open_in_full_rounded, size: 15),
          label: const Text('Full screen'),
          style: TextButton.styleFrom(foregroundColor: cobalt, visualDensity: VisualDensity.compact),
        ),
      ]),
      const SizedBox(height: 10),
      _pianoPanel(),
      const SizedBox(height: 12),
      _feedbackPanel(),
      const SizedBox(height: 14),
      _lessonControls(),
      const SizedBox(height: 12),
      _noteGuide(),
    ],
  );

  Widget _welcomeCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF203C9C), Color(0xFF315BFF), Color(0xFF4B9BFF)]),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: cobalt.withOpacity(.22), blurRadius: 24, offset: const Offset(0, 12))],
    ),
    child: Stack(children: [
      Positioned(right: -12, top: -15, child: Icon(Icons.music_note_rounded, size: 112, color: Colors.white.withOpacity(.10))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(20)), child: const Text('LESSON OF THE DAY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
        const SizedBox(height: 13),
        const Text('Every song starts\nwith one note.', style: TextStyle(color: Colors.white, fontSize: 25, height: 1.12, fontWeight: FontWeight.w900, letterSpacing: -.6)),
        const SizedBox(height: 8),
        Text('Listen. Practice. Play it by yourself.', style: TextStyle(color: Colors.white.withOpacity(.82), fontSize: 12)),
        const SizedBox(height: 17),
        GestureDetector(
          onTap: () => _playDemo(),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_arrow_rounded, color: cobalt, size: 19), SizedBox(width: 5), Text('Start learning', style: TextStyle(color: cobalt, fontWeight: FontWeight.w900, fontSize: 12))])),
        ),
      ]),
    ]),
  );

  Widget _songCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE8EDF7))),
    child: Row(children: [
      Container(width: 52, height: 52, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE3ECFF), Color(0xFFF1F5FF)]), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.music_note_rounded, color: cobalt, size: 28)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(song.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 3),
        Text(song.subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF8994AA))),
        const SizedBox(height: 7),
        Row(children: [const Icon(Icons.signal_cellular_alt_rounded, size: 12, color: Color(0xFF23B58A)), const SizedBox(width: 4), Text(song.level, style: const TextStyle(fontSize: 10, color: Color(0xFF23A982), fontWeight: FontWeight.w800)), const SizedBox(width: 10), Icon(Icons.timer_outlined, size: 12, color: Colors.blueGrey.shade300), const SizedBox(width: 3), Text('${song.bpm} BPM', style: const TextStyle(fontSize: 10, color: Color(0xFF8994AA)))]),
      ])),
      IconButton(onPressed: () => _playDemo(), icon: const Icon(Icons.play_circle_fill_rounded, color: cobalt, size: 34)),
    ]),
  );

  Widget _pianoPanel() => Container(
    padding: const EdgeInsets.fromLTRB(10, 13, 10, 10),
    decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(21), boxShadow: [BoxShadow(color: navy.withOpacity(.16), blurRadius: 20, offset: const Offset(0, 9))]),
    child: Column(children: [
      Row(children: [
        const Text('PLAY THE KEYS', style: TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w900)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(8)), child: const Text('2 OCTAVES', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 12),
      SizedBox(height: 156, child: _keyboard()),
      const SizedBox(height: 9),
      const Text('Tap a key to hear its note · Hold multiple keys to play together', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 9)),
    ]),
  );

  Widget _keyboard() {
    const whiteMidis = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83];
    const blackOffsets = {61: 0, 63: 1, 66: 3, 68: 4, 70: 5, 73: 7, 75: 8, 78: 10, 80: 11, 82: 12};
    return LayoutBuilder(builder: (context, constraints) {
      final whiteWidth = constraints.maxWidth / whiteMidis.length;
      return Stack(clipBehavior: Clip.none, children: [
        Row(children: whiteMidis.map((midi) {
          final isActive = activeMidi == midi || (mode == 'practice' && targetIndex < song.notes.length && song.notes[targetIndex] == midi);
          return Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _pressKey(midi),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF9DEBFF) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                border: Border.all(color: const Color(0xFFD8DEEA), width: .7),
                boxShadow: isActive ? [const BoxShadow(color: cyan, blurRadius: 10)] : null,
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(noteNames[midi % 12], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isActive ? cobalt : const Color(0xFF66728A))),
                Text(solfegeLabel(midi), style: const TextStyle(fontSize: 7, color: Color(0xFF9AA4B6))),
              ]),
            ),
          ));
        }).toList()),
        ...blackOffsets.entries.map((entry) {
          final midi = entry.key;
          final left = (entry.value + 1) * whiteWidth - whiteWidth * .31;
          final isActive = activeMidi == midi || (mode == 'practice' && targetIndex < song.notes.length && song.notes[targetIndex] == midi);
          return Positioned(
            left: left, top: 0, width: whiteWidth * .62, height: 91,
            child: GestureDetector(
              onTapDown: (_) => _pressKey(midi),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                decoration: BoxDecoration(
                  color: isActive ? cobalt : const Color(0xFF26334F),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                  border: Border.all(color: const Color(0xFF53617D), width: .7),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.24), blurRadius: 5, offset: const Offset(0, 3))],
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(noteNames[midi % 12], style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
              ),
            ),
          );
        }),
      ]);
    });
  }

  Widget _feedbackPanel() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(15)),
    child: Row(children: [
      Container(width: 31, height: 31, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Icon(mode == 'complete' ? Icons.check_rounded : Icons.lightbulb_outline_rounded, color: cobalt, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Text(feedback, style: const TextStyle(fontSize: 11, color: Color(0xFF34446C), fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _lessonControls() => Column(children: [
    Row(children: [
      Expanded(child: _actionButton(Icons.hearing_rounded, 'Listen', onPressed: isPlayingDemo ? null : () => _playDemo())),
      const SizedBox(width: 8),
      Expanded(child: _actionButton(Icons.school_rounded, 'Practice', onPressed: () => _startPractice())),
    ]),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: _actionButton(Icons.psychology_alt_rounded, 'Play alone', onPressed: () => _startPractice(challenge: true), primary: true)),
      const SizedBox(width: 8),
      Expanded(child: _actionButton(Icons.refresh_rounded, 'Try again', onPressed: _resetPractice)),
    ]),
    if (mode == 'practice' || mode == 'challenge') ...[
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: targetIndex / song.notes.length, minHeight: 7, backgroundColor: const Color(0xFFE1E8F8), color: cobalt)),
      const SizedBox(height: 5),
      Text('$targetIndex / ${song.notes.length} notes', style: const TextStyle(fontSize: 9, color: Color(0xFF8994AA), fontWeight: FontWeight.w700)),
    ],
  ]);

  Widget _actionButton(IconData icon, String label, {VoidCallback? onPressed, bool primary = false}) => SizedBox(
    height: 44,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? cobalt : Colors.white,
        foregroundColor: primary ? Colors.white : navy,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: primary ? cobalt : const Color(0xFFE5EAF4))),
      ),
    ),
  );

  Widget _noteGuide() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8EDF7))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('THE 7 MUSICAL NOTES', style: TextStyle(fontSize: 9, color: Color(0xFF8994AA), fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(7, (i) {
        const names = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];
        const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
        return Column(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(letters[i], style: const TextStyle(color: cobalt, fontWeight: FontWeight.w900))),
          const SizedBox(height: 5),
          Text(names[i], style: const TextStyle(fontSize: 9, color: navy, fontWeight: FontWeight.w800)),
        ]);
      })),
    ]),
  );

  Widget _libraryPage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    children: [
      const Text('Song library', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 5),
      const Text('Pick a melody. We’ll teach it one note at a time.', style: TextStyle(fontSize: 12, color: Color(0xFF8994AA))),
      const SizedBox(height: 18),
      ...List.generate(songs.length, (i) {
        final selected = i == songIndex;
        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: GestureDetector(
            onTap: () { _selectSong(i); setState(() => selectedTab = 0); },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? cobalt : const Color(0xFFE8EDF7), width: selected ? 1.5 : 1)),
              child: Row(children: [
                Container(width: 45, height: 45, decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.music_note_rounded, color: cobalt)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(songs[i].title, style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${songs[i].subtitle} · ${songs[i].level}', style: const TextStyle(color: Color(0xFF8994AA), fontSize: 10)),
                ])),
                Icon(selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: cobalt),
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(17)), child: const Row(children: [Icon(Icons.auto_awesome_rounded, color: cobalt), SizedBox(width: 10), Expanded(child: Text('More songs and difficulty levels can be added to your learning path.', style: TextStyle(color: Color(0xFF34446C), fontSize: 11, fontWeight: FontWeight.w600)))])),
    ],
  );

  Widget _progressPage() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('Your progress', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 5),
      const Text('Every minute at the piano makes a difference.', style: TextStyle(fontSize: 12, color: Color(0xFF8994AA))),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _progressTile(Icons.bolt_rounded, '$xp', 'Total XP', const Color(0xFFFFA928))),
        const SizedBox(width: 10),
        Expanded(child: _progressTile(Icons.music_note_rounded, '$completedSongs', 'Songs learned', const Color(0xFF315BFF))),
      ]),
      const SizedBox(height: 10),
      _progressTile(Icons.local_fire_department_rounded, '$streak day', 'Current streak', const Color(0xFFFF765E), wide: true),
      const SizedBox(height: 20),
      const Text('Learning path', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: navy)),
      const SizedBox(height: 12),
      ...['Meet the piano keys', 'Learn Do Re Mi', 'Play your first melody', 'Practice rhythm', 'Play a song from memory'].asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 29, height: 29, decoration: BoxDecoration(color: e.key == 0 ? cobalt : const Color(0xFFEAF0FF), shape: BoxShape.circle), alignment: Alignment.center, child: Text('${e.key + 1}', style: TextStyle(color: e.key == 0 ? Colors.white : cobalt, fontWeight: FontWeight.w900, fontSize: 11))),
          const SizedBox(width: 11),
          Expanded(child: Text(e.value, style: const TextStyle(color: navy, fontWeight: FontWeight.w700, fontSize: 12))),
          Icon(e.key == 0 ? Icons.play_circle_fill_rounded : Icons.lock_outline_rounded, color: e.key == 0 ? cobalt : const Color(0xFFB4BDCE), size: 18),
        ]),
      )),
    ],
  );

  Widget _progressTile(IconData icon, String value, String label, Color color, {bool wide = false}) => Container(
    width: wide ? double.infinity : null,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE8EDF7))),
    child: Row(children: [
      Container(width: 39, height: 39, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: navy, fontSize: 19, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Color(0xFF8994AA), fontSize: 10)),
      ]),
    ]),
  );

  Widget _bottomNav() => Container(
    padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
    decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: const Color(0xFFE8EDF7)))),
    child: Row(children: [
      _navItem(Icons.home_rounded, 'Learn', 0),
      _navItem(Icons.library_music_rounded, 'Songs', 1),
      _navItem(Icons.insights_rounded, 'Progress', 2),
    ]),
  );

  Widget _navItem(IconData icon, String label, int index) {
    final selected = selectedTab == index;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: selected ? cobalt : const Color(0xFF9AA4B6), size: 21),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: selected ? cobalt : const Color(0xFF9AA4B6), fontSize: 9, fontWeight: FontWeight.w800)),
      ]),
    ));
  }
}


class FullScreenPianoPage extends StatefulWidget {
  final ValueChanged<int> onKeyPressed;
  final String songTitle;

  const FullScreenPianoPage({
    super.key,
    required this.onKeyPressed,
    required this.songTitle,
  });

  @override
  State<FullScreenPianoPage> createState() => _FullScreenPianoPageState();
}

class _FullScreenPianoPageState extends State<FullScreenPianoPage> {
  int activeMidi = -1;
  Timer? _releaseTimer;

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _play(int midi) {
    widget.onKeyPressed(midi);
    setState(() => activeMidi = midi);
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => activeMidi = -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1530),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxHeight < 360;
          return Padding(
            padding: EdgeInsets.fromLTRB(18, compact ? 5 : 12, 18, compact ? 7 : 14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: 'Close piano',
                    ),
                    const SizedBox(width: 6),
                    const Text('PIANO', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.09), borderRadius: BorderRadius.circular(20)),
                      child: Text(widget.songTitle, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    const Icon(Icons.touch_app_rounded, color: Color(0xFF8DA8FF), size: 17),
                    const SizedBox(width: 6),
                    const Text('PLAY ANY KEY', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
                SizedBox(height: compact ? 4 : 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(10, compact ? 7 : 12, 10, compact ? 7 : 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF172544),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF34476E)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 24, offset: const Offset(0, 10))],
                    ),
                    child: LayoutBuilder(builder: (context, keyArea) {
                      const whiteNotes = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83];
                      const blackOffsets = {61: 0, 63: 1, 66: 3, 68: 4, 70: 5, 73: 7, 75: 8, 78: 10, 80: 11, 82: 12};
                      final whiteWidth = keyArea.maxWidth / whiteNotes.length;
                      final blackHeight = keyArea.maxHeight * .59;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: whiteNotes.map((midi) {
                              final selected = activeMidi == midi;
                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (_) => _play(midi),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 70),
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: selected ? const Color(0xFF9DEBFF) : const Color(0xFFFAFBFF),
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                      border: Border.all(color: const Color(0xFFD5DDED), width: .8),
                                      boxShadow: selected ? [const BoxShadow(color: cyan, blurRadius: 13)] : null,
                                    ),
                                    alignment: Alignment.bottomCenter,
                                    padding: EdgeInsets.only(bottom: compact ? 7 : 12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(noteNames[midi % 12], style: TextStyle(fontSize: compact ? 9 : 12, fontWeight: FontWeight.w900, color: selected ? cobalt : const Color(0xFF53617D))),
                                        Text(solfegeLabel(midi), style: TextStyle(fontSize: compact ? 7 : 9, color: const Color(0xFF8994AA))),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          ...blackOffsets.entries.map((entry) {
                            final midi = entry.key;
                            final selected = activeMidi == midi;
                            return Positioned(
                              left: (entry.value + 1) * whiteWidth - whiteWidth * .31,
                              top: 0,
                              width: whiteWidth * .62,
                              height: blackHeight,
                              child: GestureDetector(
                                onTapDown: (_) => _play(midi),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 70),
                                  decoration: BoxDecoration(
                                    color: selected ? cobalt : const Color(0xFF101A31),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                                    border: Border.all(color: const Color(0xFF53617D), width: .8),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 6, offset: const Offset(0, 3))],
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  padding: EdgeInsets.only(bottom: compact ? 6 : 9),
                                  child: Text(noteNames[midi % 12], style: TextStyle(color: Colors.white, fontSize: compact ? 7 : 9, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ),
                ),
                SizedBox(height: compact ? 5 : 9),
                Text(
                  'C4 – B5   •   2 OCTAVES   •   Tap the keys to play',
                  style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .5),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
