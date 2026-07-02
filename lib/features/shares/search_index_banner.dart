import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/app_service.dart';

/// LAN search token index build progress (global across shares).
class SearchIndexProgressBanner extends ConsumerWidget {
  const SearchIndexProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appServiceProvider).searchIndexStatus;
    return ValueListenableBuilder<SearchIndexState>(
      valueListenable: status,
      builder: (context, state, _) => _SearchIndexProgressBody(state: state),
    );
  }
}

class SearchIndexShareStatus extends StatelessWidget {
  const SearchIndexShareStatus({super.key, required this.state});

  final SearchIndexState state;

  @override
  Widget build(BuildContext context) {
    if (!state.building) {
      return const SizedBox.shrink();
    }
    return _SearchIndexProgressBody(
      state: state,
      compact: true,
    );
  }
}

class _SearchIndexProgressBody extends StatelessWidget {
  const _SearchIndexProgressBody({
    required this.state,
    this.compact = false,
  });

  final SearchIndexState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!state.building) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final total = state.indexed + state.remaining;
    final progress = total == 0 ? null : state.indexed / total;
    final label = total == 0
        ? 'Preparing search index…'
        : 'Search index ${state.indexed} / $total files';

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.search,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Building LAN search index',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              'Shares stay available; search fills in as indexing completes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
