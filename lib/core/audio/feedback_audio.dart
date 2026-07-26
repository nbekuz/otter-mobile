import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/api/api_models.dart';
import '../../data/services/sounds_service.dart';
import '../utils/media_url.dart';

/// Plays notification / confirmation sounds selected in Settings.
class FeedbackAudio {
  FeedbackAudio(this._sounds) : _player = AudioPlayer();

  final SoundsService _sounds;
  final AudioPlayer _player;

  List<ApiSound> notification = const [];
  List<ApiSound> completion = const [];
  bool _loaded = false;
  bool _disposed = false;

  static const _fallback = <({String key, String title, String emoji})>[
    (key: 'bell', title: 'Колокольчик', emoji: '🔔'),
    (key: 'chime', title: 'Перезвон', emoji: '🎵'),
    (key: 'success', title: 'Успех', emoji: '✅'),
    (key: 'ding', title: 'Динь', emoji: '🔊'),
    (key: 'soft', title: 'Мягкий', emoji: '🎶'),
    (key: 'default', title: 'По умолчанию', emoji: '🔔'),
    (key: 'none', title: 'Без звука', emoji: '🔇'),
  ];

  List<ApiSound> fallbackFor(String category) => [
        for (var i = 0; i < _fallback.length; i++)
          ApiSound(
            key: _fallback[i].key,
            category: category,
            title: _fallback[i].title,
            emoji: _fallback[i].emoji,
            sortOrder: i,
          ),
      ];

  Future<void> ensureLoaded() async {
    if (_loaded && (notification.isNotEmpty || completion.isNotEmpty)) return;
    try {
      final results = await Future.wait([
        _sounds.fetchNotificationSounds(),
        _sounds.fetchCompletionSounds(),
      ]);
      notification = results[0].isNotEmpty
          ? results[0]
          : fallbackFor('notification');
      completion = results[1].isNotEmpty
          ? results[1]
          : fallbackFor('completion');
    } catch (e, st) {
      debugPrint('[FeedbackAudio] load failed: $e\n$st');
      if (notification.isEmpty) notification = fallbackFor('notification');
      if (completion.isEmpty) completion = fallbackFor('completion');
    } finally {
      _loaded = true;
    }
  }

  ApiSound? find(String category, String key) {
    final list = category == 'completion' ? completion : notification;
    for (final s in list) {
      if (s.key == key) return s;
    }
    for (final s in fallbackFor(category)) {
      if (s.key == key) return s;
    }
    return null;
  }

  String label(String category, String key) {
    final sound = find(category, key);
    if (sound == null) return key;
    final emoji = sound.emoji.trim();
    return emoji.isEmpty ? sound.title : '$emoji ${sound.title}';
  }

  Future<void> playKey(String category, String key) async {
    if (key.isEmpty || key == 'none') return;
    await ensureLoaded();
    final sound = find(category, key);
    await playUrl(sound?.audioUrl);
  }

  Future<void> playUrl(String? url) async {
    if (_disposed) return;
    final resolved = resolveMediaUrl(url);
    if (resolved.isEmpty) return;
    try {
      await _player.stop();
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(UrlSource(resolved));
    } catch (e, st) {
      debugPrint('[FeedbackAudio] play failed: $e\n$st');
    }
  }

  Future<void> preview(ApiSound sound) async {
    if (sound.key == 'none') return;
    await playUrl(sound.audioUrl);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
