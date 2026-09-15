import 'package:flutter/material.dart';

import '../remote_client.dart';
import '../settings.dart';
import '../theme.dart';

class AppsScreen extends StatelessWidget {
  final RemoteClient client;
  final Settings settings;
  const AppsScreen({super.key, required this.client, required this.settings, });

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('COMING NEXT', style: T.label),
      );
}
