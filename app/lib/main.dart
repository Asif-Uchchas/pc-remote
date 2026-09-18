import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_client.dart';
import 'settings.dart';
import 'share_intake.dart';
import 'theme.dart';
import 'ui/connect_screen.dart';
import 'ui/shell.dart';

final scaffoldMessenger = GlobalKey<ScaffoldMessengerState>();

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
  late final ShareIntake _share;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _share = ShareIntake(_client)..onNeedConnection = _autoConnectForShare;
  }

  /// A share arrived while disconnected: reconnect to the last PC silently.
  Future<void> _autoConnectForShare() async {
    if (_client.isConnected || _client.status == ConnectionStatus.connecting) return;
    final p = await SharedPreferences.getInstance();
    final host = p.getString('host') ?? '';
    final pin = p.getString('pin') ?? '';
    final port = int.tryParse(p.getString('port') ?? '') ?? 48889;
    if (host.isEmpty || pin.isEmpty) {
      scaffoldMessenger.currentState?.showSnackBar(
          const SnackBar(content: Text('Connect to a PC — the shared item will be sent right after')));
      return;
    }
    scaffoldMessenger.currentState?.showSnackBar(SnackBar(content: Text('Connecting to $host to send…')));
    final ok = await _client.connect(host: host, port: port, pin: pin);
    if (!ok) {
      scaffoldMessenger.currentState?.showSnackBar(
          SnackBar(content: Text('Could not reach $host: ${_client.errorMessage}')));
    }
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
    _share.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mobile Remote',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scaffoldMessengerKey: scaffoldMessenger,
        home: ListenableBuilder(
          listenable: _client,
          builder: (context, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _client.isConnected || _client.status == ConnectionStatus.reconnecting
                ? HomeShell(key: const ValueKey('home'), client: _client, settings: _settings, share: _share)
                : ConnectScreen(key: const ValueKey('connect'), client: _client),
          ),
        ),
      );
}
