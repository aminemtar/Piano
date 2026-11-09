import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

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
        colorScheme: ColorScheme.fromSeed(
            seedColor: cobalt, brightness: Brightness.light),
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

const noteNames = [
  'C',
  'C♯',
  'D',
  'D♯',
  'E',
  'F',
  'F♯',
  'G',
  'G♯',
  'A',
  'A♯',
  'B'
];
const solfege = [
  'Do',
  'Do♯',
  'Re',
  'Re♯',
  'Mi',
  'Fa',
  'Fa♯',
  'Sol',
  'Sol♯',
  'La',
  'La♯',
  'Si'
];

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
  Song('Happy Birthday', 'Traditional celebration song', 'Beginner', 100, [
    67,
    67,
    69,
    67,
    72,
    71,
    67,
    67,
    69,
    67,
    74,
    72,
    67,
    67,
    79,
    76,
    72,
    71,
    69
  ]),
  Song('Jingle Bells', 'Traditional · Holiday song', 'Beginner', 112, [
    64,
    64,
    64,
    64,
    64,
    64,
    64,
    67,
    60,
    62,
    64,
    65,
    65,
    65,
    65,
    65,
    64,
    64,
    64,
    64,
    64,
    62,
    62,
    64,
    62,
    67
  ]),
  Song('Frère Jacques', 'Traditional French nursery song', 'Beginner', 96,
      [60, 62, 64, 60, 60, 62, 64, 60, 64, 65, 67, 64, 65, 67]),
  Song('London Bridge', 'Traditional nursery song', 'Beginner', 104,
      [67, 69, 67, 65, 64, 65, 67, 64, 60, 64, 67, 67, 69, 67, 65, 64, 65, 67]),
  Song('Row, Row, Row Your Boat', 'Traditional round', 'Beginner', 92, [
    60,
    60,
    60,
    62,
    64,
    64,
    62,
    64,
    65,
    67,
    72,
    72,
    72,
    67,
    67,
    67,
    64,
    64,
    64,
    60,
    60,
    60
  ]),
  Song('Amazing Grace', 'Traditional hymn', 'Beginner', 76,
      [67, 72, 67, 71, 69, 67, 64, 60, 64, 62, 60]),
  Song('The Entertainer', 'Scott Joplin · Easy excerpt', 'Intermediate', 116,
      [64, 66, 67, 69, 64, 66, 67, 69, 64, 66, 67, 69, 72, 71, 69, 67]),
  Song('Minuet in G', 'J. S. Bach · Easy excerpt', 'Intermediate', 108,
      [67, 71, 74, 79, 76, 77, 79, 74, 76, 71, 72, 74, 67, 69, 71, 72]),
  Song('When the Saints Go Marching In', 'Traditional jazz standard',
      'Beginner', 108, [
    60,
    64,
    65,
    67,
    60,
    64,
    65,
    67,
    60,
    64,
    65,
    67,
    65,
    64,
    60,
    62,
    64,
    62,
    60
  ]),
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
  final Set<int> pressedKeys = {};
  int targetIndex = 0;
  int completedSongs = 0;
  int xp = 0;
  int streak = 1;
  String mode = 'idle';
  bool isPlayingDemo = false;
  String feedback = 'Choose a song and start learning';
  static const int _audioVoiceCount = 6;
  final List<AudioPlayer?> _players =
      List<AudioPlayer?>.filled(_audioVoiceCount, null);
  final List<Future<void>> _voiceQueues =
      List<Future<void>>.filled(_audioVoiceCount, Future<void>.value());
  final Map<int, Uint8List> _toneCache = {};
  final Map<String, List<AudioSource>> _darbukaSources = {};
  final math.Random _darbukaRandom = math.Random();
  bool _darbukaPreparing = false;
  bool _darbukaReady = false;
  bool _soloudInitialized = false;
  int _nextVoice = 0;
  bool _audioDisposed = false;
  Timer? _demoTimer;
  Timer? _hintTimer;
  Timer? _progressSaveTimer;
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

  void _scheduleProgressSave() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress() async {
    _progressSaveTimer?.cancel();
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setInt('xp', xp);
      await prefs.setInt('completed', completedSongs);
    } catch (_) {
      // Keep the in-memory progress even if local storage is temporarily unavailable.
    }
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _hintTimer?.cancel();
    _progressSaveTimer?.cancel();
    unawaited(_persistProgress());
    _audioDisposed = true;
    final cleanupTasks = <Future<void>>[];
    for (var index = 0; index < _players.length; index++) {
      final player = _players[index];
      if (player == null) continue;
      final queuedPlayback = _voiceQueues[index];
      cleanupTasks.add(
        queuedPlayback.catchError((_) {}).then((_) => player.dispose()),
      );
    }
    if (_soloudInitialized) {
      cleanupTasks.add(_disposeDarbukaAudio());
    }
    unawaited(Future.wait(cleanupTasks)
        .then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {}));
    _toneCache.clear();
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
      final sample =
          ((fundamental + harmonic2 + harmonic3) * attack * decay * 0.58)
              .clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  Future<void> _playSource(Source source) async {
    if (_audioDisposed) return;
    final voiceIndex = _nextVoice;
    _nextVoice = (_nextVoice + 1) % _audioVoiceCount;
    final player = _players[voiceIndex] ??= AudioPlayer();
    final previousTask = _voiceQueues[voiceIndex];
    final playbackTask = previousTask.catchError((_) {}).then((_) async {
      if (_audioDisposed) return;
      await player.stop();
      if (_audioDisposed) return;
      await player.play(source);
    });
    _voiceQueues[voiceIndex] = playbackTask;
    try {
      await playbackTask;
    } catch (_) {
      if (mounted && !_audioDisposed) {
        setState(() => feedback = 'Audio could not start. Please try again.');
      }
    }
  }

  Future<void> _playAudio(Uint8List audio) => _playSource(BytesSource(audio));

  Future<void> _playNote(int midi) async {
    if (_audioDisposed) return;
    final audio = _toneCache.putIfAbsent(midi, () => _makeTone(midi));
    await _playAudio(audio);
  }

  Future<String> _downloadDarbukaSample(String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/piano_darbuka_$filename');
    if (await file.exists() && await file.length() > 0) return file.path;

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(
        'https://raw.githubusercontent.com/freepats/world-percussion/main/samples/Darbuka/$filename',
      ));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
            'Darbuka sample download failed: ${response.statusCode}');
      }
      final sink = file.openWrite();
      await response.pipe(sink);
      return file.path;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _prepareDarbukaPools() async {
    if (_darbukaReady || _darbukaPreparing || _audioDisposed) return;
    _darbukaPreparing = true;
    if (mounted)
      setState(() => feedback = 'Preparing low-latency drum engine…');

    // SoLoud mixes voices natively instead of restarting a small pool of
    // platform players. Keep the buffer small but conservative for mid-range
    // Android devices to reduce latency without inviting audio underruns.
    try {
      await SoLoud.instance.init(
        sampleRate: 44100,
        bufferSize: 1024,
        channels: Channels.stereo,
        lowLatency: true,
      );
      _soloudInitialized = true;
      SoLoud.instance.setMaxActiveVoiceCount(48);

      const files = <String, List<String>>{
        'doum': [
          'doom_01_01.flac',
          'doom_01_02.flac',
          'doom_01_03.flac',
          'doom_01_04.flac'
        ],
        'tek': [
          'tak_02_01.flac',
          'tak_02_02.flac',
          'tak_02_03.flac',
          'tak_02_04.flac'
        ],
        'ka': [
          'pa_03_01.flac',
          'pa_03_02.flac',
          'pa_03_03.flac',
          'pa_03_04.flac'
        ],
      };

      final loadedEntries = await Future.wait(files.entries.map((entry) async {
        final sources = await Future.wait(entry.value.map((filename) async {
          final path = await _downloadDarbukaSample(filename);
          return SoLoud.instance.loadFile(path, mode: LoadMode.memory);
        }));
        return MapEntry(entry.key, sources);
      }));

      if (_audioDisposed) {
        for (final entry in loadedEntries) {
          for (final source in entry.value) {
            await SoLoud.instance.disposeSource(source);
          }
        }
        await SoLoud.instance.deinitAsync();
        _soloudInitialized = false;
        return;
      }

      _darbukaSources.addEntries(loadedEntries);
      _darbukaReady = true;
      if (mounted) setState(() => feedback = 'Darbuka ready — play freely');
    } catch (error) {
      if (_soloudInitialized && SoLoud.instance.isInitialized) {
        for (final sources in _darbukaSources.values) {
          for (final source in sources) {
            try {
              await SoLoud.instance.disposeSource(source);
            } catch (_) {}
          }
        }
        _darbukaSources.clear();
        try {
          await SoLoud.instance.deinitAsync();
        } catch (_) {}
        _soloudInitialized = false;
      }
      if (mounted && !_audioDisposed) {
        setState(() => feedback = 'Could not prepare drum audio: $error');
      }
    } finally {
      _darbukaPreparing = false;
    }
  }

  Future<void> _disposeDarbukaAudio() async {
    if (!_soloudInitialized || !SoLoud.instance.isInitialized) return;
    for (final sources in _darbukaSources.values) {
      for (final source in sources) {
        try {
          await SoLoud.instance.disposeSource(source);
        } catch (_) {}
      }
    }
    _darbukaSources.clear();
    try {
      await SoLoud.instance.deinitAsync();
    } catch (_) {}
    _soloudInitialized = false;
  }

  void _playDarbuka(String hit) {
    if (_audioDisposed || !_darbukaReady || !_soloudInitialized) return;
    final variations = _darbukaSources[hit];
    if (variations == null || variations.isEmpty) return;

    // Rotate through separate recordings so repeated strikes do not sound
    // identical. SoLoud creates independent native voices, allowing overlap.
    final source = variations[_darbukaRandom.nextInt(variations.length)];
    HapticFeedback.selectionClick();
    try {
      SoLoud.instance.play(
        source,
        volume: .92 + _darbukaRandom.nextDouble() * .08,
      );
    } catch (error) {
      if (mounted && !_audioDisposed) {
        setState(() => feedback = 'Drum playback failed: $error');
      }
    }
  }

  void _pressKey(int midi) {
    _playNote(midi);
    setState(() {
      pressedKeys.add(midi);
      activeMidi = midi;
    });
    if (mode == 'practice' || mode == 'challenge') {
      _checkAnswer(midi);
    }
  }

  void _releaseKey(int midi) {
    if (!mounted) return;
    setState(() {
      pressedKeys.remove(midi);
      activeMidi = pressedKeys.isEmpty ? -1 : pressedKeys.last;
    });
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
            : 'Correct! $targetIndex of ${song.notes.length} notes';
      });
      _scheduleProgressSave();
      if (targetIndex == song.notes.length) _finishSong();
    } else {
      setState(() => feedback =
          'Not quite — try ${noteLabel(expected)} (${solfegeLabel(expected)})');
      if (mode == 'practice') {
        _hintTimer?.cancel();
        _hintTimer = Timer(const Duration(milliseconds: 350), () {
          if (mounted && mode == 'practice') _playNote(expected);
        });
      }
    }
  }

  void _finishSong() {
    _demoTimer?.cancel();
    _hintTimer?.cancel();
    setState(() {
      mode = 'complete';
      completedSongs = math.max(completedSongs, songIndex + 1).toInt();
      feedback = 'Song completed! You earned ${song.notes.length * 5} XP.';
    });
    unawaited(_persistProgress());
  }

  Future<void> _playDemo() async {
    _demoTimer?.cancel();
    _hintTimer?.cancel();
    setState(() {
      mode = 'watch';
      isPlayingDemo = true;
      feedback = 'Listen and watch the highlighted keys';
      activeMidi = -1;
    });
    var i = 0;
    final interval = Duration(milliseconds: (60000 / song.bpm).round());
    Future<void> tick() async {
      if (!mounted) return;
      if (mode != 'watch' || !isPlayingDemo) return;
      if (i >= song.notes.length) {
        setState(() {
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
      if (mounted && mode == 'watch' && isPlayingDemo) {
        _demoTimer = Timer(interval, tick);
      }
    }

    await tick();
  }

  void _startPractice({bool challenge = false}) {
    _demoTimer?.cancel();
    _hintTimer?.cancel();
    setState(() {
      mode = challenge ? 'challenge' : 'practice';
      isPlayingDemo = false;
      targetIndex = 0;
      feedback = challenge
          ? 'Play the song from memory. You can do it!'
          : 'Follow the notes. The first note is ${noteLabel(song.notes.first)}';
    });
    if (!challenge) {
      _hintTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted && mode == 'practice') _playNote(song.notes.first);
      });
    }
  }

  void _resetPractice() {
    _demoTimer?.cancel();
    _hintTimer?.cancel();
    setState(() {
      targetIndex = 0;
      mode = 'ready';
      isPlayingDemo = false;
      activeMidi = pressedKeys.isEmpty ? -1 : pressedKeys.last;
      feedback = 'Ready to try again?';
    });
  }

  Future<void> _openFullScreenPiano() async {
    _demoTimer?.cancel();
    _hintTimer?.cancel();
    if (mounted) {
      setState(() {
        isPlayingDemo = false;
        if (mode == 'watch') mode = 'ready';
      });
    }
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FullScreenPianoPage(
        onNote: _playNote,
        onEarnXp: () {
          setState(() => xp += 5);
          _scheduleProgressSave();
        },
        onComplete: () {
          setState(() =>
              completedSongs = math.max(completedSongs, songIndex + 1).toInt());
          _scheduleProgressSave();
        },
        songTitle: song.title,
        notes: song.notes,
        bpm: song.bpm,
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
    _hintTimer?.cancel();
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
              child: switch (selectedTab) {
                0 => _learnPage(),
                1 => _libraryPage(),
                2 => _progressPage(),
                _ => _darbukaPage(),
              },
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [cobalt, Color(0xFF6E8BFF)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: cobalt.withValues(alpha: .22),
                      blurRadius: 14,
                      offset: const Offset(0, 6))
                ],
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 11),
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('piano.',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: navy,
                          letterSpacing: -.7)),
                  Text('YOUR MUSIC JOURNEY',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8490AA),
                          letterSpacing: 1.5)),
                ]),
            const Spacer(),
            _statPill(Icons.bolt_rounded, '$xp XP', const Color(0xFFFFA928)),
            const SizedBox(width: 8),
            _statPill(Icons.local_fire_department_rounded, '$streak',
                const Color(0xFFFF765E)),
          ],
        ),
      );

  Widget _statPill(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE8ECF5))),
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: navy))
        ]),
      );

  Widget _learnPage() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        children: [
          _welcomeCard(),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Continue learning',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
            TextButton(
                onPressed: () => setState(() => selectedTab = 1),
                child: const Text('All songs')),
          ]),
          _songCard(),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Your piano',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
            TextButton.icon(
              onPressed: _openFullScreenPiano,
              icon: const Icon(Icons.open_in_full_rounded, size: 15),
              label: const Text('Full screen'),
              style: TextButton.styleFrom(
                  foregroundColor: cobalt,
                  visualDensity: VisualDensity.compact),
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
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF203C9C),
                Color(0xFF315BFF),
                Color(0xFF4B9BFF)
              ]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: cobalt.withValues(alpha: .22),
                blurRadius: 24,
                offset: const Offset(0, 12))
          ],
        ),
        child: Stack(children: [
          Positioned(
              right: -12,
              top: -15,
              child: Icon(Icons.music_note_rounded,
                  size: 112, color: Colors.white.withValues(alpha: .10))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('LESSON OF THE DAY',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2))),
            const SizedBox(height: 13),
            const Text('Every song starts\nwith one note.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6)),
            const SizedBox(height: 8),
            Text('Listen. Practice. Play it by yourself.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .82), fontSize: 12)),
            const SizedBox(height: 17),
            GestureDetector(
              onTap: () => _playDemo(),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow_rounded, color: cobalt, size: 19),
                    SizedBox(width: 5),
                    Text('Start learning',
                        style: TextStyle(
                            color: cobalt,
                            fontWeight: FontWeight.w900,
                            fontSize: 12))
                  ])),
            ),
          ]),
        ]),
      );

  Widget _songCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFE8EDF7))),
        child: Row(children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE3ECFF), Color(0xFFF1F5FF)]),
                  borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.music_note_rounded,
                  color: cobalt, size: 28)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(song.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: navy)),
                const SizedBox(height: 3),
                Text(song.subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF8994AA))),
                const SizedBox(height: 7),
                Row(children: [
                  const Icon(Icons.signal_cellular_alt_rounded,
                      size: 12, color: Color(0xFF23B58A)),
                  const SizedBox(width: 4),
                  Text(song.level,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF23A982),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Icon(Icons.timer_outlined,
                      size: 12, color: Colors.blueGrey.shade300),
                  const SizedBox(width: 3),
                  Text('${song.bpm} BPM',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF8994AA)))
                ]),
              ])),
          IconButton(
              onPressed: () => _playDemo(),
              icon: const Icon(Icons.play_circle_fill_rounded,
                  color: cobalt, size: 34)),
        ]),
      );

  Widget _pianoPanel() => Container(
        padding: const EdgeInsets.fromLTRB(10, 13, 10, 10),
        decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                  color: navy.withValues(alpha: .16),
                  blurRadius: 20,
                  offset: const Offset(0, 9))
            ]),
        child: Column(children: [
          Row(children: [
            const Text('PLAY THE KEYS',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('2 OCTAVES',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 12),
          SizedBox(height: 156, child: _keyboard()),
          const SizedBox(height: 9),
          const Text(
              'Tap a key to hear its note · Hold multiple keys to play together',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 9)),
        ]),
      );

  Widget _keyboard() {
    const whiteMidis = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83];
    const blackOffsets = {
      61: 0,
      63: 1,
      66: 3,
      68: 4,
      70: 5,
      73: 7,
      75: 8,
      78: 10,
      80: 11,
      82: 12
    };
    return LayoutBuilder(builder: (context, constraints) {
      final whiteWidth = constraints.maxWidth / whiteMidis.length;
      return Stack(clipBehavior: Clip.none, children: [
        Row(
            children: whiteMidis.map((midi) {
          final isActive = activeMidi == midi ||
              (mode == 'practice' &&
                  targetIndex < song.notes.length &&
                  song.notes[targetIndex] == midi);
          return Expanded(
              child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _pressKey(midi),
            onTapUp: (_) => _releaseKey(midi),
            onTapCancel: () => _releaseKey(midi),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 75),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                  0, pressedKeys.contains(midi) ? 5 : 0, 0),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF9DEBFF) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(7)),
                border: Border.all(color: const Color(0xFFD8DEEA), width: .7),
                boxShadow: isActive
                    ? [const BoxShadow(color: cyan, blurRadius: 10)]
                    : null,
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(children: [
                Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(noteNames[midi % 12],
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isActive
                                      ? cobalt
                                      : const Color(0xFF66728A))),
                          Text(solfegeLabel(midi),
                              style: const TextStyle(
                                  fontSize: 7, color: Color(0xFF9AA4B6))),
                        ])),
              ]),
            ),
          ));
        }).toList()),
        ...blackOffsets.entries.map((entry) {
          final midi = entry.key;
          final left = (entry.value + 1) * whiteWidth - whiteWidth * .31;
          final isActive = activeMidi == midi ||
              (mode == 'practice' &&
                  targetIndex < song.notes.length &&
                  song.notes[targetIndex] == midi);
          return Positioned(
            left: left,
            top: 0,
            width: whiteWidth * .62,
            height: 91,
            child: GestureDetector(
              onTapDown: (_) => _pressKey(midi),
              onTapUp: (_) => _releaseKey(midi),
              onTapCancel: () => _releaseKey(midi),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 75),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(
                    0, pressedKeys.contains(midi) ? 5 : 0, 0),
                decoration: BoxDecoration(
                  color: isActive ? cobalt : const Color(0xFF26334F),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(6)),
                  border: Border.all(color: const Color(0xFF53617D), width: .7),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: .24),
                        blurRadius: 5,
                        offset: const Offset(0, 3))
                  ],
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 7),
                child: Stack(children: [
                  Align(
                      alignment: Alignment.bottomCenter,
                      child: Text(noteNames[midi % 12],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w800))),
                ]),
              ),
            ),
          );
        }),
      ]);
    });
  }

  Widget _feedbackPanel() => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  mode == 'complete'
                      ? Icons.check_rounded
                      : Icons.lightbulb_outline_rounded,
                  color: cobalt,
                  size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(feedback,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF34446C),
                      fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _lessonControls() => Column(children: [
        Row(children: [
          Expanded(
              child: _actionButton(Icons.hearing_rounded, 'Listen',
                  onPressed: isPlayingDemo ? null : () => _playDemo())),
          const SizedBox(width: 8),
          Expanded(
              child: _actionButton(Icons.school_rounded, 'Practice',
                  onPressed: () => _startPractice())),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _actionButton(Icons.psychology_alt_rounded, 'Play alone',
                  onPressed: () => _startPractice(challenge: true),
                  primary: true)),
          const SizedBox(width: 8),
          Expanded(
              child: _actionButton(Icons.refresh_rounded, 'Try again',
                  onPressed: _resetPractice)),
        ]),
        if (mode == 'practice' || mode == 'challenge') ...[
          const SizedBox(height: 12),
          ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                  value: targetIndex / song.notes.length,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE1E8F8),
                  color: cobalt)),
          const SizedBox(height: 5),
          Text('$targetIndex / ${song.notes.length} notes',
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF8994AA),
                  fontWeight: FontWeight.w700)),
        ],
      ]);

  Widget _actionButton(IconData icon, String label,
          {VoidCallback? onPressed, bool primary = false}) =>
      SizedBox(
        height: 44,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary ? cobalt : Colors.white,
            foregroundColor: primary ? Colors.white : navy,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
                side: BorderSide(
                    color: primary ? cobalt : const Color(0xFFE5EAF4))),
          ),
        ),
      );

  Widget _noteGuide() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EDF7))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('THE 7 MUSICAL NOTES',
              style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFF8994AA),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1)),
          const SizedBox(height: 10),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                const names = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];
                const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
                return Column(children: [
                  Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: const Color(0xFFEAF0FF),
                          borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Text(letters[i],
                          style: const TextStyle(
                              color: cobalt, fontWeight: FontWeight.w900))),
                  const SizedBox(height: 5),
                  Text(names[i],
                      style: const TextStyle(
                          fontSize: 9,
                          color: navy,
                          fontWeight: FontWeight.w800)),
                ]);
              })),
        ]),
      );

  Widget _libraryPage() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          const Text('Song library',
              style: TextStyle(
                  fontSize: 25, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 5),
          const Text('Pick a melody. We’ll teach it one note at a time.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8994AA))),
          const SizedBox(height: 18),
          ...List.generate(songs.length, (i) {
            final selected = i == songIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: GestureDetector(
                onTap: () {
                  _selectSong(i);
                  setState(() => selectedTab = 0);
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: selected ? cobalt : const Color(0xFFE8EDF7),
                          width: selected ? 1.5 : 1)),
                  child: Row(children: [
                    Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FF),
                            borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.music_note_rounded,
                            color: cobalt)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(songs[i].title,
                              style: const TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${songs[i].subtitle} · ${songs[i].level}',
                              style: const TextStyle(
                                  color: Color(0xFF8994AA), fontSize: 10)),
                        ])),
                    Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.chevron_right_rounded,
                        color: cobalt),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(17)),
              child: const Row(children: [
                Icon(Icons.auto_awesome_rounded, color: cobalt),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'More songs and difficulty levels can be added to your learning path.',
                        style: TextStyle(
                            color: Color(0xFF34446C),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)))
              ])),
        ],
      );

  Widget _progressPage() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Your progress',
              style: TextStyle(
                  fontSize: 25, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 5),
          const Text('Every minute at the piano makes a difference.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8994AA))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _progressTile(Icons.bolt_rounded, '$xp', 'Total XP',
                    const Color(0xFFFFA928))),
            const SizedBox(width: 10),
            Expanded(
                child: _progressTile(
                    Icons.music_note_rounded,
                    '$completedSongs',
                    'Songs learned',
                    const Color(0xFF315BFF))),
          ]),
          const SizedBox(height: 10),
          _progressTile(Icons.local_fire_department_rounded, '$streak day',
              'Current streak', const Color(0xFFFF765E),
              wide: true),
          const SizedBox(height: 20),
          const Text('Learning path',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 12),
          ...[
            'Meet the piano keys',
            'Learn Do Re Mi',
            'Play your first melody',
            'Practice rhythm',
            'Play a song from memory'
          ].asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                          color: e.key == 0 ? cobalt : const Color(0xFFEAF0FF),
                          shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${e.key + 1}',
                          style: TextStyle(
                              color: e.key == 0 ? Colors.white : cobalt,
                              fontWeight: FontWeight.w900,
                              fontSize: 11))),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Text(e.value,
                          style: const TextStyle(
                              color: navy,
                              fontWeight: FontWeight.w700,
                              fontSize: 12))),
                  Icon(
                      e.key == 0
                          ? Icons.play_circle_fill_rounded
                          : Icons.lock_outline_rounded,
                      color: e.key == 0 ? cobalt : const Color(0xFFB4BDCE),
                      size: 18),
                ]),
              )),
        ],
      );

  Widget _progressTile(IconData icon, String value, String label, Color color,
          {bool wide = false}) =>
      Container(
        width: wide ? double.infinity : null,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE8EDF7))),
        child: Row(children: [
          Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: const TextStyle(
                    color: navy, fontSize: 19, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Color(0xFF8994AA), fontSize: 10)),
          ]),
        ]),
      );

  Widget _bottomNav() => Container(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: const Color(0xFFE8EDF7)))),
        child: Row(children: [
          _navItem(Icons.home_rounded, 'Learn', 0),
          _navItem(Icons.library_music_rounded, 'Songs', 1),
          _navItem(Icons.insights_rounded, 'Progress', 2),
          _navItem(Icons.album_rounded, 'Darbuka', 3),
        ]),
      );

  Widget _darbukaPage() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text('Darbuka',
              style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: navy,
                  letterSpacing: -.7)),
          const SizedBox(height: 5),
          const Text('Play the rhythms with your fingertips.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8994AA))),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF17264A), Color(0xFF263E70)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.graphic_eq_rounded, color: cyan, size: 19),
                const SizedBox(width: 8),
                const Text('PERCUSSION STUDIO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4)),
                const Spacer(),
                Text('12 RECORDED VARIATIONS',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  _darbukaReady
                      ? Icons.check_circle_rounded
                      : Icons.downloading_rounded,
                  color: _darbukaReady
                      ? const Color(0xFF7BE2BD)
                      : const Color(0xFFFFD18A),
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  _darbukaReady
                      ? 'SOUNDS READY'
                      : _darbukaPreparing
                          ? 'LOADING DRUM ENGINE & 12 STRIKES…'
                          : 'PREPARING DRUM SAMPLES…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .8),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const SizedBox(height: 4),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: _DarbukaHeadSurface(onHit: _playDarbuka),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'TAP THE SKIN  ·  CENTER: DOUM  ·  LEFT EDGE: TEK  ·  RIGHT EDGE: KA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .68),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .65,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                  '12 separately recorded strikes are loaded into a native low-latency mixer. Fast hits can overlap instead of restarting and cutting off the previous sound.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 10,
                      height: 1.5)),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EDF7))),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Darbuka basics',
                      style: TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                  SizedBox(height: 10),
                  _DarbukaTip(
                      label: 'DOUM',
                      description:
                          'Strike the middle of the drum head for a deep bass tone.'),
                  SizedBox(height: 8),
                  _DarbukaTip(
                      label: 'TEK',
                      description:
                          'Strike near the edge for a bright, ringing tone.'),
                  SizedBox(height: 8),
                  _DarbukaTip(
                      label: 'KA',
                      description:
                          'Use a lighter rim strike for a crisp accent.'),
                ]),
          ),
        ],
      );

  Widget _navItem(IconData icon, String label, int index) {
    final selected = selectedTab == index;
    return Expanded(
        child: GestureDetector(
      onTap: () {
        setState(() => selectedTab = index);
        if (index == 3) unawaited(_prepareDarbukaPools());
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            color: selected ? cobalt : const Color(0xFF9AA4B6), size: 21),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                color: selected ? cobalt : const Color(0xFF9AA4B6),
                fontSize: 9,
                fontWeight: FontWeight.w800)),
      ]),
    ));
  }
}

class FullScreenPianoPage extends StatefulWidget {
  final Future<void> Function(int) onNote;
  final VoidCallback onEarnXp;
  final VoidCallback onComplete;
  final String songTitle;
  final List<int> notes;
  final int bpm;

  const FullScreenPianoPage({
    super.key,
    required this.onNote,
    required this.onEarnXp,
    required this.onComplete,
    required this.songTitle,
    required this.notes,
    required this.bpm,
  });

  @override
  State<FullScreenPianoPage> createState() => _FullScreenPianoPageState();
}

class _FullScreenPianoPageState extends State<FullScreenPianoPage> {
  static const _whiteNotes = [
    60,
    62,
    64,
    65,
    67,
    69,
    71,
    72,
    74,
    76,
    77,
    79,
    81,
    83,
  ];
  static const _blackNotes = [61, 63, 66, 68, 70, 73, 75, 78, 80, 82];
  int _targetIndex = 0;
  bool _completed = false;

  void _playKey(int midi) {
    widget.onNote(midi);
    if (_completed ||
        _targetIndex >= widget.notes.length ||
        widget.notes[_targetIndex] != midi) {
      return;
    }
    setState(() {
      _targetIndex++;
      _completed = _targetIndex == widget.notes.length;
    });
    widget.onEarnXp();
    if (_completed) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: navy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: Column(
              children: [
                Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close piano',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.songTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ),
                  Text('${widget.bpm} BPM',
                      style: const TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Text(
                  _completed
                      ? 'Song complete!'
                      : 'Play the highlighted note · ${_targetIndex + 1} / ${widget.notes.length}',
                  style: const TextStyle(
                      color: cyan, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(builder: (context, constraints) {
                      final whiteWidth =
                          constraints.maxWidth / _whiteNotes.length;
                      final keyboardHeight =
                          math.min(constraints.maxHeight, 330.0);
                      return SizedBox(
                        height: keyboardHeight,
                        child: Stack(children: [
                          Row(
                              children: _whiteNotes
                                  .map((midi) => Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _playKey(midi),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 2),
                                            alignment: Alignment.bottomCenter,
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            decoration: BoxDecoration(
                                              color: !_completed &&
                                                      _targetIndex <
                                                          widget.notes.length &&
                                                      widget.notes[
                                                              _targetIndex] ==
                                                          midi
                                                  ? const Color(0xFF9DEBFF)
                                                  : Colors.white,
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      bottom:
                                                          Radius.circular(9)),
                                            ),
                                            child: Text(noteLabel(midi),
                                                style: const TextStyle(
                                                    color: navy,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ),
                                        ),
                                      ))
                                  .toList()),
                          ..._blackNotes.map((midi) {
                            final precedingWhiteIndex =
                                _whiteNotes.indexOf(midi - 1);
                            final highlighted = !_completed &&
                                _targetIndex < widget.notes.length &&
                                widget.notes[_targetIndex] == midi;
                            return Positioned(
                              left: (precedingWhiteIndex + .68) * whiteWidth,
                              top: 0,
                              width: whiteWidth * .58,
                              height: keyboardHeight * .58,
                              child: GestureDetector(
                                onTap: () => _playKey(midi),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: highlighted
                                        ? cobalt
                                        : const Color(0xFF26334F),
                                    border: Border.all(
                                        color: const Color(0xFF53617D)),
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(7)),
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  padding: const EdgeInsets.only(bottom: 9),
                                  child: Text(noteLabel(midi),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                            );
                          }),
                        ]),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DarbukaTip extends StatelessWidget {
  final String label;
  final String description;
  const _DarbukaTip({required this.label, required this.description});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(
                  color: cobalt, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(description,
                style: const TextStyle(
                    color: Color(0xFF65718A), fontSize: 11, height: 1.35))),
      ]);
}

class _DarbukaHeadSurface extends StatefulWidget {
  final ValueChanged<String> onHit;

  const _DarbukaHeadSurface({required this.onHit});

  @override
  State<_DarbukaHeadSurface> createState() => _DarbukaHeadSurfaceState();
}

class _DarbukaHeadSurfaceState extends State<_DarbukaHeadSurface> {
  bool _pressed = false;
  String? _lastZone;

  String _zoneAt(Offset point, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final distance = (point - center).distance / radius;
    if (distance < .43) return 'doum';
    return point.dx < center.dx ? 'tek' : 'ka';
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final zone = _zoneAt(details.localPosition, size);
              setState(() {
                _pressed = true;
                _lastZone = zone;
              });
              widget.onHit(zone);
            },
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? .985 : 1,
              duration: const Duration(milliseconds: 65),
              curve: Curves.easeOut,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _DarbukaHeadPainter()),
                  Align(
                    alignment: const Alignment(0, .02),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _lastZone == 'doum' ? 'DOUM' : 'DOUM',
                          style: TextStyle(
                            color:
                                const Color(0xFF735A3D).withValues(alpha: .76),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: const [
                              Shadow(color: Colors.white70, blurRadius: 3)
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'DRUM SKIN',
                          style: TextStyle(
                            color:
                                const Color(0xFF8C7556).withValues(alpha: .68),
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 27,
                    top: size.height * .31,
                    child: _zoneLabel('TEK'),
                  ),
                  Positioned(
                    right: 27,
                    top: size.height * .31,
                    child: _zoneLabel('KA'),
                  ),
                  Positioned(
                    bottom: 23,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'STRIKE ANYWHERE ON THE HEAD',
                        style: TextStyle(
                          color: const Color(0xFF806A4D).withValues(alpha: .7),
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );

  Widget _zoneLabel(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF4E4030).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: const Color(0xFF8B7557).withValues(alpha: .28)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF806A4D),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      );
}

class _DarbukaHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .47;

    canvas.drawCircle(
      center.translate(0, radius * .045),
      radius * .99,
      Paint()
        ..color = const Color(0xFF050B19).withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4F6F7),
            Color(0xFF697786),
            Color(0xFFE6EBEF),
            Color(0xFF596777),
            Color(0xFFDDE3E8),
          ],
          stops: [0, .22, .48, .76, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawCircle(
      center,
      radius * .925,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8795A1), Color(0xFFE7ECEF), Color(0xFF596875)],
        ).createShader(Rect.fromCircle(center: center, radius: radius * .925)),
    );

    final skinRadius = radius * .855;
    canvas.drawCircle(
      center,
      skinRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.28, -.34),
          radius: .95,
          colors: [
            Color(0xFFFFF4D9),
            Color(0xFFE8D5B3),
            Color(0xFFC9AE83),
            Color(0xFFB6976C),
          ],
          stops: [0, .48, .82, 1],
        ).createShader(Rect.fromCircle(center: center, radius: skinRadius)),
    );

    canvas.drawCircle(
      center,
      skinRadius * .985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .012
        ..color = const Color(0xFF8C704E).withValues(alpha: .65),
    );

    // Fine, irregular pores and faint concentric wear make the membrane read
    // as stretched natural skin rather than a flat coloured touch button.
    for (var i = 0; i < 150; i++) {
      final angle = i * 2.399963229728653;
      final fraction = .16 + ((i * 37) % 79) / 100;
      final distance = skinRadius * fraction;
      final point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      canvas.drawCircle(
        point,
        (i % 3 + 1) * .34,
        Paint()
          ..color =
              const Color(0xFF856B4B).withValues(alpha: .10 + (i % 4) * .025),
      );
    }

    for (var i = 0; i < 36; i++) {
      final angle = (math.pi * 2 * i) / 36;
      final point = Offset(
        center.dx + math.cos(angle) * radius * .955,
        center.dy + math.sin(angle) * radius * .955,
      );
      canvas.drawCircle(
        point,
        radius * .018,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFF8FAFC), const Color(0xFF596777)],
          ).createShader(Rect.fromCircle(center: point, radius: radius * .018)),
      );
      canvas.drawCircle(
        point,
        radius * .006,
        Paint()..color = const Color(0xFF44515D),
      );
    }

    canvas.drawCircle(
      center.translate(-radius * .2, -radius * .28),
      radius * .55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: .19),
            Colors.white.withValues(alpha: 0)
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * .55)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
