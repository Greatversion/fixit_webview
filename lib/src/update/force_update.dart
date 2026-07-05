import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class ForceUpdateResult {
  final bool updateRequired;
  final bool forceUpdate;
  final String currentVersion;
  final String minimumVersion;
  final String? latestVersion;
  final String? updateUrl;

  const ForceUpdateResult({
    required this.updateRequired,
    required this.forceUpdate,
    required this.currentVersion,
    required this.minimumVersion,
    this.latestVersion,
    this.updateUrl,
  });

  @override
  String toString() =>
      'ForceUpdateResult(required: $updateRequired, force: $forceUpdate, '
      'current: $currentVersion, min: $minimumVersion)';
}

class FixitForceUpdate {
  static Future<ForceUpdateResult> check({
    required String currentVersion,
    required String minVersionUrl,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(minVersionUrl));
        final response = await request.close().timeout(timeout);
        if (response.statusCode != 200) {
          return ForceUpdateResult(
            updateRequired: false,
            forceUpdate: false,
            currentVersion: currentVersion,
            minimumVersion: currentVersion,
          );
        }
        final bodyStr = await response.transform(utf8.decoder).join();
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final minVersion = body['minVersion'] as String? ?? currentVersion;
        final forceUpdate = body['force'] as bool? ?? false;
        final latestVersion = body['latestVersion'] as String?;
        final updateUrl = body['updateUrl'] as String?;
        final updateRequired = isVersionLower(currentVersion, minVersion);
        return ForceUpdateResult(
          updateRequired: updateRequired,
          forceUpdate: forceUpdate,
          currentVersion: currentVersion,
          minimumVersion: minVersion,
          latestVersion: latestVersion,
          updateUrl: updateUrl,
        );
      } finally {
        client.close();
      }
    } catch (_) {
      return ForceUpdateResult(
        updateRequired: false,
        forceUpdate: false,
        currentVersion: currentVersion,
        minimumVersion: currentVersion,
      );
    }
  }

  static bool isVersionLower(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va < vb) return true;
      if (va > vb) return false;
    }
    return false;
  }

  static Future<void> showForceUpdateScreen({
    required BuildContext context,
    required ForceUpdateResult result,
    bool barrierDismissible = false,
    VoidCallback? onUpdate,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => FixitForceUpdateScreen(
        result: result,
        onUpdate: onUpdate,
      ),
    );
  }
}

class FixitForceUpdateScreen extends StatelessWidget {
  final ForceUpdateResult result;
  final VoidCallback? onUpdate;

  const FixitForceUpdateScreen({
    super.key,
    required this.result,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !result.forceUpdate,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update, size: 64),
                const SizedBox(height: 24),
                Text(
                  result.forceUpdate
                      ? 'Update Required'
                      : 'Update Available',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Version ${result.minimumVersion} is now available. '
                  'You are on ${result.currentVersion}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onUpdate,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Update Now'),
                ),
                if (!result.forceUpdate)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Later'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
