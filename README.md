# Piano — Learn by playing

A Flutter piano-learning game for Android and iOS. Start with the seven musical notes, listen to a melody, practice it with guided feedback, and then try to play it from memory.

## What is included

- Two-octave interactive piano (C4–B5), including black keys.
- Do/Re/Mi/Fa/Sol/La/Si labels alongside note letters.
- Locally synthesized piano-like tones (no streaming or external sound service).
- A bounded six-voice audio pool with cached note data to avoid creating a new audio player for every press.
- Song demonstrations with highlighted keys.
- Guided practice that checks the next expected note and repeats the expected note after a mistake.
- A challenge mode that hides note hints.
- Twelve melodies, from beginner nursery songs to intermediate excerpts: Ode to Joy, Twinkle Twinkle, Mary Had a Little Lamb, Happy Birthday, Jingle Bells, Frère Jacques, London Bridge, Row Row Row Your Boat, Amazing Grace, The Entertainer, Minuet in G, and When the Saints Go Marching In.
- Local XP and learning progress saved with SharedPreferences.
- Responsive learning, song-library, and progress screens, plus a dedicated landscape full-screen practice keyboard.
- Press-and-hold key animation with a visible down/up movement.

## Run locally

Install Flutter stable and the Android/iOS toolchains, then:

```bash
git clone https://github.com/aminemtar/Piano.git
cd Piano
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

The repository contains the Dart application source and package configuration. The `flutter create` command generates the native Android and iOS runner projects for your local Flutter SDK.

## Learning flow

1. **Listen** — the app demonstrates the selected melody and lights up each key.
2. **Practice** — play the notes in order; incorrect notes do not advance the lesson.
3. **Play alone** — replay the full melody without the note hints.
4. **Try again** — reset the song and practice until you can play it independently.

## Notes

- The piano tones are synthesized locally with a short harmonic envelope. They are intentionally lightweight and are not a sampled concert-grand piano soundbank. The audio engine reuses up to six players and caches the 24 keyboard tones; this bounds player allocation and avoids regenerating the same waveform on every press.
- Add songs by defining MIDI note sequences in `lib/main.dart`. Keep notes within MIDI 60–83 (C4–B5) unless the keyboard range is expanded, and add tests for any new range.
- MIDI keyboard input, sheet-music notation, both-hand lessons, rhythm scoring, and a larger licensed song catalog are planned next.
