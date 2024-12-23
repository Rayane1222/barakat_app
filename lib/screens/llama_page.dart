import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class LlamaPage extends StatefulWidget {
  @override
  _LlamaPageState createState() => _LlamaPageState();
}

class _LlamaPageState extends State<LlamaPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _messages = []; // List to store messages
  FlutterTts _flutterTts = FlutterTts(); // Initialize text-to-speech
  SpeechToText _speechToText = SpeechToText(); // Initialize speech-to-text
  bool _isListening = false; // Track listening state
  bool _speechEnabled = false; // Track if speech recognition is enabled
  String _wordsSpoken = ""; // Store spoken words
  double _confidenceLevel = 0; // Store confidence level

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("en-US"); // Set language
    await _flutterTts.setPitch(1.0); // Set pitch
    await _flutterTts.speak(text); // Speak the text
  }

  // Request microphone permission
  Future<void> _requestPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  void initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _requestPermission(); // Ensure permission is granted
    if (_speechEnabled) {
      setState(() {
        _isListening = true;
        _confidenceLevel = 0;
      });
      _speechToText.listen(onResult: _onSpeechResult);
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(result) {
    setState(() {
      _wordsSpoken = "${result.recognizedWords}";
      _confidenceLevel = result.confidence;
      _controller.text = _wordsSpoken; // Update the text field with recognized words
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return; // Prevent sending empty messages

    // Add user message to the list
    setState(() {
      _messages.add({'role': 'user', 'content': _controller.text});
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/chat'),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'message': _controller.text,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _messages.add({'role': 'assistant', 'content': data['response']}); // Add assistant response
        });
      } else {
        throw Exception('Failed to load response');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      _controller.clear(); // Clear the input field
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with Llama'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUserMessage = message['role'] == 'user';
                  return Align(
                    alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUserMessage ? Colors.blue[200] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message['content']!,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(labelText: 'Type your message...'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                    onPressed: _isListening ? _stopListening : _startListening, // Start/stop listening
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (_messages.isNotEmpty) {
                  String lastResponse = _messages.lastWhere((msg) => msg['role'] == 'assistant')['content']!;
                  _speak(lastResponse); // Read the response
                }
              },
              child: Text('Read Response'),
            ),
          ],
        ),
      ),
    );
  }
}