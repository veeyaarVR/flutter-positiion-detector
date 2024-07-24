import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const MyHomePage(title: 'Flutter Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  static const MethodChannel cameraChannelMethod = MethodChannel('camera_channel');

  void _incrementCounter() {
    setState(() {
      _counter++;
    });

    String dataToSend = "This is information from Flutter";
    dynamic data = {'text': dataToSend};

    // Invoke platform-specific code based on platform
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      _sendToIOS(data);
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      _sendToAndroid(data);
    }
  }

  void _sendToIOS(dynamic data) async {
    try {
      final result = await cameraChannelMethod.invokeMethod("openCamera", data);
      debugPrint("Received response from Swift: $result");
    } on PlatformException catch (e) {
      debugPrint("Failed to invoke method: '${e.message}'.");
    }
  }

  void _sendToAndroid(dynamic data) {
    // Placeholder for Android implementation using similar MethodChannel
    debugPrint("Sending data to Android: $data");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
