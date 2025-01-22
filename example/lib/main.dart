import 'package:flutter/material.dart';
import 'package:unleash_proxy_client_flutter/unleash_proxy_client_flutter.dart';
import 'package:unleash_proxy_client_flutter/unleash_context.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Unleash Integration Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Unleash Integration Demo'),
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
  bool _counterEnabled = false;


  @override
  void initState() {
    super.initState();
    var unleash = UnleashClient(
        url: Uri.parse('https://sandbox.getunleash.io/enterprise/api/frontend'),
        clientKey: 'SDKIntegration:development.f0474f4a37e60794ee8fb00a4c112de58befde962af6d5055b383ea3',
        refreshInterval: 60,
        experimental: const ExperimentalConfig(togglesStorageTTL: 60),
        appName: 'example-flutter-app');
    unleash.updateContext(UnleashContext(
        userId: '123',
        ));
    unleash.setContextFields({'userId': '1234'});
    void updateCounterEnabled(_) {
      final counterEnabled = unleash.isEnabled('counter');
      setState(() {
        _counterEnabled = counterEnabled;
      });
    }
    unleash.on('ready', updateCounterEnabled);
    unleash.on('update', updateCounterEnabled);
    unleash.start();
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} (counter is ${_counterEnabled ? 'enabled' : 'disabled'})'),
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
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _counterEnabled ? _incrementCounter : null,
        tooltip: 'Increment',
        child: _counterEnabled ? const Icon(Icons.add) : const Icon(Icons.disabled_by_default),
      ),
    );
  }
}
