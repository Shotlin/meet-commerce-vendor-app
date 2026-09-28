import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loops the new-requirement alert sound (like a ride-hailing driver app's
/// "new job" alert) until explicitly stopped — a single short chime is easy
/// to miss if the vendor isn't looking at the phone; a loop keeps ringing
/// until they actually acknowledge it.
class AlertSoundPlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  Future<void> playLoop() async {
    if (_playing) return;
    _playing = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/new_requirement_alert.mp3'));
    } catch (_) {
      // A missing/undecodable asset or a platform audio-session failure
      // must never crash the alert itself — the visual dialog still shows.
      _playing = false;
    }
  }

  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {
      // Ignore — nothing meaningful to recover from a stop() failure.
    }
  }

  void dispose() {
    _player.dispose();
  }
}

final alertSoundPlayerProvider = Provider<AlertSoundPlayer>((ref) {
  final player = AlertSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});
