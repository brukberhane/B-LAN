import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/app_service.dart';
import '../../platform/android/android_proximity_radios.dart';

String shizukuSettingsCopy(String state) {
  return switch (state) {
    'dead' => 'Start it in Shevery',
    'noPermission' || 'tooOld' => 'Needs permission',
    'ready' => 'Ready',
    _ => 'Install Shevery or Shizuku',
  };
}

class NearbySettingsSection extends ConsumerStatefulWidget {
  const NearbySettingsSection({super.key});

  @override
  ConsumerState<NearbySettingsSection> createState() =>
      _NearbySettingsSectionState();
}

class _NearbySettingsSectionState extends ConsumerState<NearbySettingsSection> {
  var _visible = true;
  var _members = true;
  var _dual = true;
  var _idle = '3';
  var _shizuku = 'Install Shevery or Shizuku';
  var _shizukuEnabled = false;
  var _wifiJoin = 'panel';
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final visible = await db.nearbyVisible();
    final members = await db.nearbyMembersCanInvite();
    final dual = await db.nearbyDualAdvert();
    final idle = await db.nearbyIdleMinutes();
    final android = !kIsWeb && Platform.isAndroid;
    final storedJoin = await db.nearbyWifiJoinChoice();
    final shizukuReady = android &&
        await db.nearbyShizukuAllowed() &&
        await AndroidShizukuConsent().state() == 'ready';
    final wifiJoin = storedJoin ?? (shizukuReady ? 'direct' : 'panel');
    final shizuku = android
        ? shizukuSettingsCopy(await AndroidShizukuConsent().state())
        : 'Install Shevery or Shizuku';
    if (!mounted) {
      return;
    }
    setState(() {
      _visible = visible;
      _members = members;
      _dual = dual;
      _idle = '$idle';
      _shizuku = shizuku;
      _shizukuEnabled = android;
      _wifiJoin = wifiJoin;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ListTile(title: Text('Nearby'));
    }
    final service = ref.read(appServiceProvider);
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Nearby visible'),
          value: _visible,
          onChanged: (value) async {
            setState(() => _visible = value);
            await service.setNearbyVisible(value);
          },
        ),
        ListTile(
          title: const Text('Idle minutes'),
          subtitle: Text(_idle),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Change idle minutes',
            onPressed: () => _editIdle(context, service),
          ),
        ),
        SwitchListTile(
          title: const Text('Members can invite'),
          value: _members,
          onChanged: (value) async {
            setState(() => _members = value);
            await service.setNearbyMembersCanInvite(value);
          },
        ),
        if (_shizukuEnabled)
          SwitchListTile(
            title: const Text('Extra legacy advert'),
            subtitle: const Text(
              'Adds a compat advert so older receivers see this device',
            ),
            value: _dual,
            onChanged: (value) async {
              setState(() => _dual = value);
              await service.setNearbyDualAdvert(value);
            },
          ),
        if (_shizukuEnabled)
          ListTile(
            title: const Text('Change Wi-Fi'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _wifiJoin == 'direct'
                      ? 'Direct. Shizuku connects. A miss does not open the sheet.'
                      : 'Panel. The system Wi-Fi sheet switches the network.',
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'direct', label: Text('Direct')),
                    ButtonSegment(value: 'panel', label: Text('Panel')),
                  ],
                  selected: {_wifiJoin},
                  onSelectionChanged: (value) async {
                    final next = value.first;
                    setState(() => _wifiJoin = next);
                    await service.setNearbyWifiJoin(next);
                  },
                ),
              ],
            ),
          ),
        ListTile(
          title: const Text('Shizuku'),
          subtitle: Text(_shizuku),
          enabled: _shizukuEnabled,
        ),
      ],
    );
  }

  Future<void> _editIdle(BuildContext context, AppService service) async {
    final controller = TextEditingController(text: _idle);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Idle minutes'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final minutes = int.tryParse(next ?? '');
    if (minutes == null) {
      return;
    }
    await service.setNearbyIdleMinutes(minutes);
    if (mounted) {
      setState(() => _idle = '$minutes');
    }
  }
}
