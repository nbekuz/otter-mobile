import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../utils/media_url.dart';

class PomodoroAudio {
  PomodoroAudio() : _background = AudioPlayer(), _effect = AudioPlayer() {
    _subscriptions.add(
      _background.onPlayerStateChanged.listen((state) {
        debugPrint('[PomodoroAudio] background state → $state');
      }),
    );
    _subscriptions.add(
      _background.onLog.listen((msg) {
        debugPrint('[PomodoroAudio] background log: $msg');
      }),
    );
    _subscriptions.add(
      _effect.onPlayerStateChanged.listen((state) {
        debugPrint('[PomodoroAudio] effect state → $state');
      }),
    );
    _subscriptions.add(
      _effect.onLog.listen((msg) {
        debugPrint('[PomodoroAudio] effect log: $msg');
      }),
    );
  }

  final AudioPlayer _background;
  final AudioPlayer _effect;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  String? _loopingUrl;
  bool _disposed = false;

  Future<void> playBackgroundLoop(String? url) async {
    final resolved = resolveMediaUrl(url);
    debugPrint(
      '[PomodoroAudio] playBackgroundLoop raw=$url resolved=$resolved',
    );

    if (resolved.isEmpty) {
      debugPrint('[PomodoroAudio] empty URL — stopping background');
      await stopBackground();
      return;
    }

    if (_loopingUrl == resolved) {
      final playerState = _background.state;
      debugPrint('[PomodoroAudio] same URL, current state=$playerState');
      if (playerState == PlayerState.playing) return;
      if (playerState == PlayerState.paused) {
        try {
          await _background.resume();
          debugPrint('[PomodoroAudio] background resumed');
        } catch (e, st) {
          debugPrint('[PomodoroAudio] resume FAILED: $e\n$st');
          _loopingUrl = null;
        }
        return;
      }
    }

    await _effect.stop();
    await _background.stop();
    _loopingUrl = resolved;

    try {
      await _background.setPlayerMode(PlayerMode.mediaPlayer);
      await _background.setReleaseMode(ReleaseMode.loop);
      debugPrint('[PomodoroAudio] starting background play…');
      await _background.play(UrlSource(resolved));
      debugPrint(
        '[PomodoroAudio] background play OK, state=${_background.state}',
      );
    } catch (e, st) {
      debugPrint('[PomodoroAudio] background play FAILED: $e\n$st');
      _loopingUrl = null;
    }
  }

  Future<void> playOnce(String? url) async {
    final resolved = resolveMediaUrl(url);
    debugPrint('[PomodoroAudio] playOnce raw=$url resolved=$resolved');

    if (resolved.isEmpty) {
      debugPrint('[PomodoroAudio] empty URL — skip effect');
      return;
    }

    try {
      await _effect.stop();
      await _effect.setPlayerMode(PlayerMode.mediaPlayer);
      await _effect.setReleaseMode(ReleaseMode.release);
      debugPrint('[PomodoroAudio] starting effect play…');
      await _effect.play(UrlSource(resolved));
      debugPrint('[PomodoroAudio] effect play OK, state=${_effect.state}');
    } catch (e, st) {
      debugPrint('[PomodoroAudio] effect play FAILED: $e\n$st');
    }
  }

  /// Pauza — pozitsiya saqlanadi.
  Future<void> pauseBackground() async {
    if (_loopingUrl == null) return;
    try {
      await _background.pause();
      debugPrint('[PomodoroAudio] background paused');
    } catch (e, st) {
      debugPrint('[PomodoroAudio] pause FAILED: $e\n$st');
    }
  }

  /// To‘liq to‘xtatish — keyingi play boshidan.
  Future<void> stopBackground() async {
    try {
      await _background.stop();
      debugPrint('[PomodoroAudio] background stopped');
    } catch (e, st) {
      debugPrint('[PomodoroAudio] stop background FAILED: $e\n$st');
    }
    _loopingUrl = null;
  }

  Future<void> stopEffect() async {
    try {
      await _effect.stop();
      debugPrint('[PomodoroAudio] effect stopped');
    } catch (e, st) {
      debugPrint('[PomodoroAudio] stop effect FAILED: $e\n$st');
    }
  }

  Future<void> stopAll() async {
    await stopBackground();
    await stopEffect();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    _subscriptions.clear();
    await stopAll();
    await _background.dispose();
    await _effect.dispose();
  }
}
