import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/downloads/downloads_page.dart';
import '../features/peers/peers_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shares/shares_page.dart';
import '../features/uploads/uploads_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      if (!kIsWeb) const SharesPage(),
      const PeersPage(),
      const SearchPage(),
      if (!kIsWeb) const UploadsPage(),
      const DownloadsPage(),
      const SettingsPage(),
    ];
    final destinations = <NavigationDestination>[
      if (!kIsWeb)
        const NavigationDestination(
          icon: Icon(Icons.folder_shared_outlined),
          label: 'Shares',
        ),
      const NavigationDestination(
        icon: Icon(Icons.devices_other_outlined),
        label: 'Peers',
      ),
      const NavigationDestination(
        icon: Icon(Icons.search_outlined),
        label: 'Search',
      ),
      if (!kIsWeb)
        const NavigationDestination(
          icon: Icon(Icons.upload_outlined),
          label: 'Uploads',
        ),
      const NavigationDestination(
        icon: Icon(Icons.download_outlined),
        label: 'Downloads',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        label: 'Settings',
      ),
    ];

    if (_index >= pages.length) {
      _index = 0;
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            labelType: NavigationRailLabelType.all,
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: d.icon,
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}
