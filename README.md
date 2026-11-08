# Piano — Learn by playing

A Flutter piano-learning game for Android and iOS. Start with the seven musical notes, listen to a melody, practice it with guided feedback, and then try to play it from memory.

## What is included

- Two-octave interactive piano (C4–B5), including black keys.
- Do/Re/Mi/Fa/Sol/La/Si labels alongside note letters.
- Synthesized piano-like tones generated locally at runtime (no streamed audio or external sound service).
- Song demonstrations with highlighted keys.
- Guided practice that checks the next expected note and repeats the expected note after a mistake.
- A challenge mode that hides note hints.
- Beginner song library: Ode to Joy, Twinkle Twinkle, and Mary Had a Little Lamb.
- Local XP and learning progress saved with SharedPreferences.
- Responsive learning, song-library, and progress screens.

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

- The initial piano uses a lightweight synthesized tone with a short harmonic envelope. It is a functional learning prototype, not a sampled concert-grand piano soundbank.
- The initial song catalog uses short beginner melodies. Add more songs by defining their MIDI note sequences in `lib/main.dart`.
- MIDI keyboard input, sheet-music notation, both-hand lessons, rhythm scoring, and a larger licensed song catalog are planned next.
