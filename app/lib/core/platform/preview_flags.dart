/// Compile-time switches for review builds only.
///
/// `flutter build` / CI must not pass these. Both default off, so a normal
/// release keeps lesson gates and plays bundled audio. `tool/tests/test_preview_and_facts.py`
/// fails if a release entrypoint sets them.
const kPreviewUnlock = bool.fromEnvironment('PREVIEW_UNLOCK');

/// Trailing-slash base URL for streaming review audio. Empty in real builds.
const kPreviewAudioBase = String.fromEnvironment('PREVIEW_AUDIO_BASE');
