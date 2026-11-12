/// Offline voices policy for the audio player (monetisation Option B, owner decision t298).
///
/// Premium keeps downloaded lesson clips in the persistent versioned cache (offline). Without it, a clip that
/// is not bundled still plays online: it is fetched into a per-session folder that is wiped on the next start.
/// The Arrival pack download writes straight into the persistent cache and is always free; the 419 bundled
/// clips always play from the APK.
abstract final class OfflineVoices {
  /// Evaluated per clip, so a purchase or restore takes effect immediately. Set by the app at start-up.
  static bool Function() allowed = () => true;
}
