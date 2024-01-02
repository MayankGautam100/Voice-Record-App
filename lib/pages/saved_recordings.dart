import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

class SavedRecordingsScreen extends StatefulWidget {
  const SavedRecordingsScreen({super.key});

  @override
  SavedRecordingsScreenState createState() => SavedRecordingsScreenState();
}

class SavedRecordingsScreenState extends State<SavedRecordingsScreen> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final _storage = FirebaseStorage.instance;
  final List<String> _audioUrls = [];
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _signInAnonymously();
    _fetchAudioUrls();

    // listen to play, pause, stop states
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    // listen to audio duration
    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });

    // listen to audio position
    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _position = newPosition;
      });
    });
  }

  // sign in anonymously to Firebase
  Future<void> _signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
    }
  }

  Future<void> _fetchAudioUrls() async {
    try {
      final ListResult result = await _storage.ref('recordings').list();
      print(result.items);
      final List<String> urls = await Future.wait(
          result.items.map((Reference ref) => ref.getDownloadURL()).toList());

      setState(() {
        _audioUrls.addAll(urls);
      });
    } catch (error) {
      print('Error fetching audio URLs: $error');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    await _audioPlayer.play(UrlSource(url));
    setState(() {
      _isPlaying = true;
    });
  }

  String formatTime(Duration duration) {
    String time(int n) => n.toString().padLeft(2, '0');
    final minutes = time(duration.inMinutes.remainder(60));
    final seconds = time(duration.inSeconds.remainder(60));

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recordings'),
      ),
      body: ListView.builder(
        itemCount: _audioUrls.length,
        itemBuilder: (context, index) {
          String audioUrl = _audioUrls[index];
          return ListTile(
            title: Text('Recording ${index + 1}'),
            subtitle: Text(
              _audioUrls[index].split('?').first.split('/o/').last, //file name
              style: const TextStyle(color: Colors.grey),
            ),
            leading: Icon(
              _isPlaying && _audioPlayer.source.toString() == audioUrl
                  ? Icons.volume_up
                  : Icons.music_note,
              color: Colors.blue,
            ),
            onTap: () {
              print(audioUrl);
              _playAudio(audioUrl);
            },
          );
        },
      ),
      bottomSheet: Visibility(
        visible: _isPlaying,
        child: Container(
          color: Colors.blue,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: _duration.inSeconds.toDouble(),
                value: _position.inSeconds.toDouble(),
                onChanged: (value) async {
                  final position = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(position);
                  await _audioPlayer.resume();
                },
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatTime(_position)),
                    Text(formatTime(_duration - _position)),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 35,
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  iconSize: 50,
                  onPressed: () async {
                    if (_isPlaying) {
                      await _audioPlayer.pause();
                    } else {
                      await _audioPlayer.resume();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
