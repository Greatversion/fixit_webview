import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

/// Result of a remote version check, indicating whether an update is
/// required, enforced, and where to obtain it.
class ForceUpdateResult {
  /// Whether the current version is below the minimum required version.
  final bool updateRequired;

  /// Whether the update is mandatory (user cannot dismiss the prompt).
  final bool forceUpdate;

  /// The version string of the currently installed app.
  final String currentVersion;

  /// The minimum acceptable version string from the remote config.
  final String minimumVersion;

  /// The latest available version string, if provided by the remote.
  final String? latestVersion;

  /// A URL where the user can download the update.
  final String? updateUrl;

  /// Creates a [ForceUpdateResult] from the given version data.
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

/// Provides version-check and force-update UI logic for app updates.
///
/// Fetches the minimum required version from a remote JSON endpoint and
/// compares it against the currently installed version.
class FixitForceUpdate {
  /// Checks the remote [minVersionUrl] for the minimum required version and
  /// returns a [ForceUpdateResult]. Falls back to no-update on error.
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

  /// Compares two dotted version strings (e.g. "1.2.3") and returns `true`
  /// if version [a] is lower than version [b].
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

  /// Displays a full-screen force-update dialog using the given [result].
  /// When [barrierDismissible] is `false` and [ForceUpdateResult.forceUpdate]
  /// is `true`, the user cannot dismiss the dialog.
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

/// A full-screen dialog that informs the user about a required or available
/// app update and provides an action to update.
class FixitForceUpdateScreen extends StatelessWidget {
  /// The result of the version check that determines what to display.
  final ForceUpdateResult result;

  /// Optional callback invoked when the user taps the "Update Now" button.
  final VoidCallback? onUpdate;

  /// Creates a [FixitForceUpdateScreen] for the given [result].
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
