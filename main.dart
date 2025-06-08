import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:palette_generator/palette_generator.dart';
import 'now_playing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

ValueNotifier<Map<String, dynamic>?> currentSongNotifier = ValueNotifier(null);
ValueNotifier<Color> miniPlayerColorNotifier = ValueNotifier(Colors.green[700]!);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify Básico',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer player = AudioPlayer();

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  List<DocumentSnapshot> _songsList = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    player.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    player.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Canciones")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('songs').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                _songsList = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: _songsList.length,
                  itemBuilder: (context, index) {
                    final song = _songsList[index];

                    final bool isPlaying = currentSongNotifier.value != null &&
                        currentSongNotifier.value!['songId'] == song.id &&
                        (currentSongNotifier.value!['isPlaying'] ?? true);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: isPlaying ? Colors.greenAccent.withOpacity(0.3) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            song['imageUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
                          ),
                        ),
                        title: Text(song['title']),
                        subtitle: Text('${song['author']} - ${song['interpreter']} (${song['year']})'),
                        trailing: IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_circle : Icons.play_arrow,
                            size: 32,
                            color: isPlaying ? Colors.green : null,
                          ),
                          onPressed: () async {
                            if (isPlaying) {
                              await player.pause();
                              currentSongNotifier.value = {
                                ...?currentSongNotifier.value,
                                'isPlaying': false,
                              };
                            } else {
                              await player.play(UrlSource(song['audioUrl']));

                              final PaletteGenerator paletteGenerator =
                              await PaletteGenerator.fromImageProvider(
                                NetworkImage(song['imageUrl']),
                              );

                              miniPlayerColorNotifier.value =
                                  paletteGenerator.dominantColor?.color ?? Colors.green[700]!;

                              _currentIndex = index;

                              currentSongNotifier.value = {
                                'songId': song.id,
                                'title': song['title'],
                                'imageUrl': song['imageUrl'],
                                'audioUrl': song['audioUrl'],
                                'author': song['author'],
                                'interpreter': song['interpreter'],
                                'year': song['year'],
                                'isPlaying': true,
                              };
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget buildMiniPlayer() {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: currentSongNotifier,
      builder: (context, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

        final isPlaying = currentSong['isPlaying'] ?? true;

        return ValueListenableBuilder<Color>(
          valueListenable: miniPlayerColorNotifier,
          builder: (context, miniPlayerColor, _) {
            return AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => NowPlayingScreen(
                        player: player,
                        currentSong: currentSong,
                        currentPosition: _currentPosition,
                        totalDuration: _totalDuration,
                        songs: FirebaseFirestore.instance.collection('songs').snapshots(),
                      ),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        );
                      },
                    ),
                  );
                },
                child: Container(
                  color: miniPlayerColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              currentSong['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.music_note, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              currentSong['title'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                            onPressed: () async {
                              if (_currentIndex > 0) {
                                _currentIndex--;
                                await _playSongAtIndex(_currentIndex);
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_circle : Icons.play_circle,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () async {
                              if (isPlaying) {
                                await player.pause();
                              } else {
                                await player.resume();
                              }

                              currentSongNotifier.value = {
                                ...?currentSongNotifier.value,
                                'isPlaying': !isPlaying,
                              };
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                            onPressed: () async {
                              if (_currentIndex < _songsList.length - 1) {
                                _currentIndex++;
                                await _playSongAtIndex(_currentIndex);
                              }
                            },
                          ),
                        ],
                      ),
                      Slider(
                        activeColor: Colors.white,
                        inactiveColor: Colors.white38,
                        min: 0,
                        max: _totalDuration.inMilliseconds.toDouble(),
                        value: _currentPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds).toDouble(),
                        onChanged: (value) {
                          player.seek(Duration(milliseconds: value.toInt()));
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(_currentPosition),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            formatDuration(_totalDuration),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _playSongAtIndex(int index) async {
    final song = _songsList[index];

    await player.play(UrlSource(song['audioUrl']));

    final PaletteGenerator paletteGenerator =
    await PaletteGenerator.fromImageProvider(
      NetworkImage(song['imageUrl']),
    );

    miniPlayerColorNotifier.value =
        paletteGenerator.dominantColor?.color ?? Colors.green[700]!;

    currentSongNotifier.value = {
      'songId': song.id,
      'title': song['title'],
      'imageUrl': song['imageUrl'],
      'audioUrl': song['audioUrl'],
      'author': song['author'],
      'interpreter': song['interpreter'],
      'year': song['year'],
      'isPlaying': true,
    };
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
