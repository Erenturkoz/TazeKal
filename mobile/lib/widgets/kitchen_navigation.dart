import 'package:flutter/material.dart';
import '../design/taze_theme.dart';

/// Keeps the primary action within the navigation area, clear of stock cards.
class KitchenNavigation extends StatelessWidget {
  const KitchenNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
    this.busy = false,
    this.expiredCount = 0,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final bool busy;
  final int expiredCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: theme.navigationBarTheme.backgroundColor ?? scheme.surface,
      shape: Border(
        top: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final roomy =
                    constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final navigation = NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelected,
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: 'Mutfağım',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.schedule_outlined),
                      selectedIcon: Icon(Icons.schedule_rounded),
                      label: 'Hatırlatmalar',
                    ),
                    NavigationDestination(
                      icon: Badge.count(
                        count: expiredCount,
                        isLabelVisible: expiredCount > 0,
                        child: const Icon(Icons.history_outlined),
                      ),
                      selectedIcon: Badge.count(
                        count: expiredCount,
                        isLabelVisible: expiredCount > 0,
                        child: const Icon(Icons.history_rounded),
                      ),
                      label: 'Geçmiş',
                    ),
                  ],
                );
                if (roomy) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          TazeSpace.page,
                          TazeSpace.md,
                          TazeSpace.page,
                          TazeSpace.xs,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: busy ? null : onAdd,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Ürün ekle'),
                          ),
                        ),
                      ),
                      navigation,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: navigation),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TazeSpace.xs,
                        TazeSpace.sm,
                        TazeSpace.md,
                        TazeSpace.sm,
                      ),
                      child: SizedBox(
                        width: 84,
                        height: 56,
                        child: FilledButton(
                          onPressed: busy ? null : onAdd,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                TazeRadius.lg,
                              ),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, size: 22),
                              SizedBox(height: 1),
                              Text(
                                'Ürün ekle',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
