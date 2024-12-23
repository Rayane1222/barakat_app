import 'dart:io';
import 'dart:typed_data';  // Import for Uint8List
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;  // Import the image package

class FruitClassificationPage extends StatefulWidget {
  const FruitClassificationPage({Key? key}) : super(key: key);

  @override
  _FruitClassificationPageState createState() => _FruitClassificationPageState();
}

class _FruitClassificationPageState extends State<FruitClassificationPage> {
  File? _image;
  List? _output;
  bool _loading = false;
  Interpreter? _interpreter;  // Interpreter from tflite_flutter
  List<String> _labels = [];  // To store the class labels

  @override
  void initState() {
    super.initState();
    _loading = true;
    loadModel().then((value) {
      setState(() {
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _interpreter?.close();  // Close the interpreter when the widget is disposed
    super.dispose();
  }

  // Load the tflite model using Interpreter.fromAsset
  Future<void> loadModel() async {
    try {
      // Load model and labels
      _interpreter = await Interpreter.fromAsset('assets/llm/barakat_fruits_model.tflite');
      String labelFile = await DefaultAssetBundle.of(context).loadString('assets/models/labels.txt');
      _labels = labelFile.split('\n');  // Load labels from file
      print("Model and labels loaded successfully");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  // Run the model on the selected image
  Future<void> classifyImage(File image) async {
    var inputImage = await image.readAsBytes();
    var input = await _preprocessImage(inputImage);

    var output = List.filled(1, List.filled(10, 0.0));  // Adjusted shape: [1, 10]
    _interpreter?.run(input, output);

    // Find the class with the highest probability
    int predictedClassIndex = output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));

    // Get the label corresponding to the highest probability
    String predictedClassLabel = _labels[predictedClassIndex];
    
    setState(() {
      _output = [predictedClassLabel];  // Store the predicted class label
      _loading = false;
    });
  }

  // Preprocess image (resize to 32x32 and no normalization)
  Future<List<List<List<List<int>>>>> _preprocessImage(List<int> imageBytes) async {
    // Load image using the image package
    img.Image? image = img.decodeImage(Uint8List.fromList(imageBytes));

    if (image == null) {
      throw Exception("Unable to decode image");
    }

    // Resize the image to 32x32
    img.Image resizedImage = img.copyResize(image, width: 32, height: 32);

    // Convert the resized image to a 4D tensor format: [batch, height, width, channels]
    var imageTensor = List.generate(1, (i) {
      return List.generate(32, (j) {
        return List.generate(32, (k) {
          var pixel = resizedImage.getPixel(k, j);
          // Get RGB values directly without normalization
          return [
            img.getRed(pixel),   // Red channel
            img.getGreen(pixel), // Green channel
            img.getBlue(pixel),  // Blue channel
          ];
        });
      });
    });

    // Return the preprocessed image as a list (batch size of 1)
    return imageTensor;
  }

  // Pick image from the gallery
  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _loading = true;
        _image = File(image.path);
      });
      classifyImage(File(image.path));
    }
  }

  // Pick image from the camera
  Future<void> pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _loading = true;
        _image = File(image.path);
      });
      classifyImage(File(image.path));
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text("Fruits Classifier"),
      centerTitle: true,
    ),
    body: Center( // Center the entire body
      child: _loading
          ? CircularProgressIndicator() // Show loading indicator in the center
          : Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center the column content
              children: <Widget>[
                SizedBox(height: 20),
                _image == null
                    ? Text("No image selected")
                    : Image.file(_image!, height: 250, width: 250),
                SizedBox(height: 20),
                _output != null
                    ? Text(
                        "Predicted: ${_output![0]}",  // Display the predicted class label
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                        ),
                      )
                    : Container(),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: pickImage,
                  child: Text("Pick Image from Gallery"),
                ),
                ElevatedButton(
                  onPressed: pickImageFromCamera,
                  child: Text("Pick Image from Camera"),
                ),
              ],
            ),
    ),
  );
}
}