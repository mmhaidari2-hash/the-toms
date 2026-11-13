/// Production host for streamed lesson clips ([SpeechInput.remoteBase] on Android).
/// Override at compile time only, never from a remote JSON (that could redirect
/// audio to an untrusted host):
/// `--dart-define=AUDIO_CDN_BASE_URL=https://cdn.example.com/the-toms/assets/`
/// Trailing slash required; keep the same path layout (`assets/audio/<id>.mp3`).
const kAudioCdnBaseUrl = String.fromEnvironment(
  'AUDIO_CDN_BASE_URL',
  defaultValue: 'https://mmhaidari2-hash.github.io/the-toms/assets/',
);
