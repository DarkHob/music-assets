import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // 👈 Importa para usar currentSongNotifier

class NowPlayingScreen extends StatefulWidget {
  final AudioPlayer player;
  final Map<String, dynamic> currentSong;
  final Duration currentPosition;
  final Duration totalDuration;
  final Stream<QuerySnapshot> songs;

  const NowPlayingScreen({
    super.key,
    required this.player,
    required this.currentSong,
    required this.currentPosition,
    required this.totalDuration,
    required this.songs,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  late List<DocumentSnapshot> _songsList;
  int _currentIndex = 0;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();

    _currentPosition = widget.currentPosition;
    _totalDuration = widget.totalDuration;

    widget.player.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    widget.player.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> playSong(DocumentSnapshot song) async {
    await widget.player.play(UrlSource(song['audioUrl']));
    setState(() {
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _isPlaying = true;
    });

    // 🚀 Actualiza ValueNotifier
    currentSongNotifier.value = {
      'songId': song.id,
      'title': song['title'],
      'imageUrl': song['imageUrl'],
      'audioUrl': song['audioUrl'],
      'author': song['author'],
      'interpreter': song['interpreter'],
      'year': song['year'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.songs,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _songsList = snapshot.data!.docs;
        _currentIndex = _songsList.indexWhere((song) => song.id == currentSongNotifier.value?['songId']);

        final currentSong = currentSongNotifier.value;

        if (currentSong == null) {
          // Si no hay canción actual (por ejemplo si pausamos desde el mini player)
          return const Scaffold(
            body: Center(child: Text("No hay canción en reproducción")),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Now Playing"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context); // ✅ No hace falta pasar result
              },
            ),
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  currentSong['imageUrl'],
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.music_note, size: 100),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                currentSong['title'],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${currentSong['author']} - ${currentSong['interpreter']}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Slider(
                activeColor: Colors.green,
                inactiveColor: Colors.green[200],
                min: 0,
                max: _totalDuration.inMilliseconds.toDouble(),
                value: _currentPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds).toDouble(),
                onChanged: (value) {
                  widget.player.seek(Duration(milliseconds: value.toInt()));
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(_currentPosition)),
                    Text(formatDuration(_totalDuration)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 48),
                    onPressed: () {
                      if (_currentIndex > 0) {
                        _currentIndex--;
                        playSong(_songsList[_currentIndex]);
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 64,
                      color: Colors.green[700],
                    ),
                    onPressed: () async {
                      if (_isPlaying) {
                        await widget.player.pause();
                      } else {
                        await widget.player.resume();
                      }
                      setState(() {
                        _isPlaying = !_isPlaying;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 48),
                    onPressed: () {
                      if (_currentIndex < _songsList.length - 1) {
                        _currentIndex++;
                        playSong(_songsList[_currentIndex]);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
