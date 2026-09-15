import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'remote_client.dart';
import 'ui/connect_screen.dart';
import 'ui/control_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const PcRemoteApp());
}

class PcRemoteApp extends StatefulWidget {
  const PcRemoteApp({super.key});

  @override
  State<PcRemoteApp> createState() => _PcRemoteAppState();
}

class _PcRemoteAppState extends State<PcRemoteApp> {
  final _client = RemoteClient();

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1E78DC);
    return MaterialApp(
      title: 'PC Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: _client,
        builder: (context, _) => _client.isConnected
            ? ControlScreen(client: _client)
            : ConnectScreen(client: _client),
      ),
    );
  }
}
