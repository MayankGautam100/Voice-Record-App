import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({Key? key}) : super(key: key);

  @override
  RecordingScreenState createState() => RecordingScreenState();
}

class RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  final _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _recorderIsReady = false;
  String _filePath = '';
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _initRecorder();

    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  Future _initRecorder() async {
    final requestStatus = await Permission.microphone.request();

    if (requestStatus != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission denied'),
          backgroundColor: Colors.red,
          duration: Duration(milliseconds: 3000),
        ),
      );
      throw ('Microphone permission denied');
    }

    _audioRecorder.openRecorder();
    _recorderIsReady = true;

    _audioRecorder.setSubscriptionDuration(
      const Duration(milliseconds: 500),
    ); //how often progress is updated
  }

  @override
  void dispose() {
    _audioRecorder.closeRecorder();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!_recorderIsReady) return;

    final Directory appDocDirectory = await getApplicationDocumentsDirectory();
    final String filePath = '${appDocDirectory.path}/recording.wav';

    await _audioRecorder.startRecorder(toFile: filePath);

    setState(() {
      _isRecording = true;
      _filePath = filePath;
    });
  }

  Future<void> _stopRecording() async {
    if (!_recorderIsReady) return;

    setState(() {
      _isRecording = false;
    });

    await _audioRecorder.stopRecorder();
  }

  Future<void> _saveRecordingToFirebase() async {
    try {
      if (_filePath.isNotEmpty) {
        final File audioFile = File(_filePath);
        final String fileName =
            'recordings/${DateTime.now().millisecondsSinceEpoch}.wav';

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saving file to Firebase...'),
          ),
        );

        await FirebaseStorage.instance.ref(fileName).putFile(audioFile);

        // Show a snackbar if recording is saved
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording saved to Firebase successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('No recording found to save.');
      }
    } catch (error) {
      // Show a snackbar if saving fails
      print(error);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save recording to Firebase.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording)
              Container(
                height: 100,
                child: _buildZigZagPattern(),
              ),
            if (_isRecording)
              const SizedBox(
                height: 10,
              ),
            if (_isRecording)
              StreamBuilder<RecordingDisposition>(
                stream: _audioRecorder.onProgress,
                builder: (context, snapshot) {
                  final duration = snapshot.hasData
                      ? snapshot.data!.duration
                      : Duration.zero;

                  String time(int n) => n.toString().padLeft(2, '0');
                  final minutes = time(duration.inMinutes.remainder(60));
                  final seconds = time(duration.inSeconds.remainder(60));

                  return Text(
                    '$minutes:$seconds',
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ElevatedButton(
              onPressed: () {
                if (_isRecording) {
                  _stopRecording();
                  _saveRecordingToFirebase();
                } else {
                  _startRecording();
                }
              },
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZigZagPattern() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(10, (index) {
            final height = 50 +
                20 * (1 + index % 3) * (1 - 2 * (index % 2)) * _animation.value;
            return Container(
              width: 15,
              height: height >= 0 ? height : 0,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.blue : Colors.blue[200],
              ),
            );
          }),
        );
      },
    );
  }
}
