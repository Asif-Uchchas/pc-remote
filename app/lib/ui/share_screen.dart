import 'package:flutter/material.dart';

import '../remote_client.dart';
import '../theme.dart';

class ShareScreen extends StatelessWidget {
  final RemoteClient client;
  
  const ShareScreen({super.key, required this.client, });

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('COMING NEXT', style: T.label),
      );
}
