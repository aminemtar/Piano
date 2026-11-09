# Piano — Learn by playing

A Flutter piano-learning game for Android and iOS. Start with the seven musical notes, listen to a melody, practice it with guided feedback, and then try to play it from memory.

## What is included

- Two-octave interactive piano (C4–B5), including black keys.
- A dedicated darbuka percussion studio using 12 real recorded strikes across Doum, Tek, and Ka, with variation playback and a native low-latency mixer.
- Do/Re/Mi/Fa/Sol/La/Si labels alongside note letters.
- Sampled acoustic Kawai upright piano engine using the CC0 FreePats Upright Piano KW recordings, with stereo sample playback, velocity-aware notes, polyphony, and natural note-off release.
- Native SoLoud audio engine shared by the sampled piano and percussion. Piano sample archive is downloaded once and cached in app storage; darbuka recordings are downloaded and cached on-device.
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

- The piano uses FreePats Upright Piano KW, a real Kawai upright recording released under CC0 1.0. Its SFZ archive is downloaded on first launch, stored in application support storage, and reused offline afterward. The first download requires an internet connection. Source: https://github.com/freepats/upright-piano-KW
- Darbuka recordings are from the FreePats World Percussion collection, licensed CC0 1.0. The app downloads twelve short FLAC variations when the percussion studio is first opened, caches them in the device temporary directory, and preloads them into SoLoud memory for overlapping playback. An internet connection is required during the first preparation. Source: https://github.com/freepats/world-percussion
- Add songs by defining MIDI note sequences in `lib/main.dart`. Keep notes within MIDI 60–83 (C4–B5) unless the keyboard range is expanded, and add tests for any new range.
- MIDI keyboard input, sheet-music notation, both-hand lessons, rhythm scoring, and a larger licensed song catalog are planned next.
