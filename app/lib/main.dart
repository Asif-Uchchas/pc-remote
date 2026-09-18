import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'remote_client.dart';
import 'settings.dart';
import 'theme.dart';
import 'ui/connect_screen.dart';
import 'ui/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: T.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MobileRemoteApp());
}

class MobileRemoteApp extends StatefulWidget {
  const MobileRemoteApp({super.key});

  @override
  State<MobileRemoteApp> createState() => _MobileRemoteAppState();
}

class _MobileRemoteAppState extends State<MobileRemoteApp> with WidgetsBindingObserver {
  final _client = RemoteClient();
  final _settings = Settings()..load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop pings / reconnect attempts while the app is not on screen so the
    // radio can idle; resume (and re-check the link) when it comes back.
    _client.setPaused(state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mobile Remote',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: _client,
          builder: (context, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _client.isConnected || _client.status == ConnectionStatus.reconnecting
                ? HomeShell(key: const ValueKey('home'), client: _client, settings: _settings)
                : ConnectScreen(key: const ValueKey('connect'), client: _client),
          ),
        ),
      );
}
