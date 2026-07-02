import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class SecuritySettingsSection extends ConsumerStatefulWidget {
  const SecuritySettingsSection({super.key});

  @override
  ConsumerState<SecuritySettingsSection> createState() =>
      _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends ConsumerState<SecuritySettingsSection> {
  var _loaded = false;
  double _tokenTtlDays = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = ref.read(appServiceProvider);
    final hours = await app.browserTokenTtlHours();
    if (!mounted) {
      return;
    }
    setState(() {
      _tokenTtlDays = hours / 24;
      _loaded = true;
    });
  }

  Future<void> _saveTtl() async {
    final hours = (_tokenTtlDays * 24).round();
    await ref.read(appServiceProvider).setBrowserTokenTtlHours(hours);
    ref.invalidate(browserTokenProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Browser token expiry updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || kIsWeb) {
      return const SizedBox.shrink();
    }

    final app = ref.watch(appServiceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Security', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Secret storage'),
          subtitle: Text(
            app.usesSecureStorage
                ? 'Device keys and browser token use platform secure storage.'
                : 'Secure storage unavailable — secrets kept in encrypted app DB settings fallback.',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tokenTtlDays <= 0
                ? 'Browser token expiry: never'
                : 'Browser token expiry: ${_tokenTtlDays.toStringAsFixed(0)} days',
          ),
          subtitle: const Text('0 = token stays valid until rotated/revoked.'),
          trailing: SizedBox(
            width: 160,
            child: Slider(
              value: _tokenTtlDays.clamp(0, 90),
              min: 0,
              max: 90,
              divisions: 18,
              label: _tokenTtlDays <= 0 ? '0' : '${_tokenTtlDays.round()}d',
              onChanged: (value) => setState(() => _tokenTtlDays = value),
              onChangeEnd: (_) => _saveTtl(),
            ),
          ),
        ),
      ],
    );
  }
}
