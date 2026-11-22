import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/varanti_brand.dart';
import '../dashboard/scan_flow.dart';
import '../warranties/widgets/warranty_card.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _sortLabel(WarrantySortOrder order) {
    return switch (order) {
      WarrantySortOrder.expiringSoonest => 'Soonest',
      WarrantySortOrder.newest => 'Newest',
      WarrantySortOrder.highestValue => 'Value',
    };
  }

  void _showSortSheet(BuildContext context, WarrantySortOrder current) {
    final hairline = AppTheme.hairlineOf(context);
    final crimson = AppTheme.crimsonOf(context);
    final notifier = ref.read(warrantyFilterProvider.notifier);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sort Warranties',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _SortOptionRow(
                icon: Icons.schedule_rounded,
                title: 'Expiring Soonest',
                subtitle: 'Prioritize items nearing expiration',
                selected: current == WarrantySortOrder.expiringSoonest,
                accentColor: crimson,
                onTap: () {
                  notifier.updateSortOrder(WarrantySortOrder.expiringSoonest);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 8),
              _SortOptionRow(
                icon: Icons.calendar_today_outlined,
                title: 'Newest Purchases',
                subtitle: 'Most recently purchased items first',
                selected: current == WarrantySortOrder.newest,
                accentColor: crimson,
                onTap: () {
                  notifier.updateSortOrder(WarrantySortOrder.newest);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 8),
              _SortOptionRow(
                icon: Icons.payments_outlined,
                title: 'Highest Value',
                subtitle: 'Sort by purchase price descending',
                selected: current == WarrantySortOrder.highestValue,
                accentColor: crimson,
                onTap: () {
                  notifier.updateSortOrder(WarrantySortOrder.highestValue);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    ref.read(warrantyFilterProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(warrantyFilterProvider);
    final allAsync = ref.watch(warrantiesStreamProvider);
    final filteredAsync = ref.watch(filteredWarrantiesProvider);

    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final crimson = AppTheme.crimsonOf(context);

    final hasActiveFilter = (filter.query != null && filter.query!.isNotEmpty) ||
        filter.selectedCategory != null ||
        filter.selectedStatus != null;

    final totalCount = allAsync.asData?.value.length ?? 0;
    final visibleCount = filteredAsync.asData?.value.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const Text('Vault'),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: ShapeDecoration(
                color: subtle,
                shape: StadiumBorder(side: BorderSide(color: hairline)),
              ),
              child: Text(
                hasActiveFilter ? '$visibleCount / $totalCount' : '$totalCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: StadiumBorder(side: BorderSide(color: hairline)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => _showSortSheet(context, filter.sortOrder),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_vert_rounded, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        _sortLabel(filter.sortOrder),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Capsule Search Bar (SRS 4.1 UI-02)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items, stores, serials, or tags...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: (filter.query != null && filter.query!.isNotEmpty) ||
                        _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(warrantyFilterProvider.notifier).updateQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (val) {
                ref.read(warrantyFilterProvider.notifier).updateQuery(val);
              },
            ),
          ),

          // Status Filter Pill Row
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _StatusFilterPill(
                  label: 'All Status',
                  selected: filter.selectedStatus == null,
                  onTap: () => ref
                      .read(warrantyFilterProvider.notifier)
                      .updateStatus(null),
                ),
                const SizedBox(width: 8),
                _StatusFilterPill(
                  label: 'Active',
                  dotColor: AppTheme.statusActive,
                  selected: filter.selectedStatus == 'active',
                  onTap: () => ref
                      .read(warrantyFilterProvider.notifier)
                      .updateStatus('active'),
                ),
                const SizedBox(width: 8),
                _StatusFilterPill(
                  label: 'Expiring Soon',
                  dotColor: AppTheme.statusExpiringSoon,
                  selected: filter.selectedStatus == 'expiring_soon',
                  onTap: () => ref
                      .read(warrantyFilterProvider.notifier)
                      .updateStatus('expiring_soon'),
                ),
                const SizedBox(width: 8),
                _StatusFilterPill(
                  label: 'Expired',
                  dotColor: crimson,
                  selected: filter.selectedStatus == 'expired',
                  onTap: () => ref
                      .read(warrantyFilterProvider.notifier)
                      .updateStatus('expired'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Category Filter Pill Row (SRS FR-WAR-03)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CategoryPill(
                  label: 'All Categories',
                  selected: filter.selectedCategory == null,
                  onTap: () => ref
                      .read(warrantyFilterProvider.notifier)
                      .updateCategory(null),
                ),
                ...AppConfig.categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _CategoryPill(
                      label: cat,
                      selected: filter.selectedCategory == cat,
                      onTap: () => ref
                          .read(warrantyFilterProvider.notifier)
                          .updateCategory(cat),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Filtered Warranties List
          Expanded(
            child: filteredAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: crimson, strokeWidth: 2.5),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 42, color: crimson),
                      const SizedBox(height: 12),
                      Text(
                        ErrorMessages.friendly(
                          err,
                          fallback: "Couldn't load your warranties right now.",
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        onPressed: () => ref.invalidate(warrantiesStreamProvider),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _VaultEmptyState(
                    hasActiveFilter: hasActiveFilter,
                    onClearFilters: _clearAllFilters,
                    onScan: () => ScanFlowHelper.showSourcePicker(context, ref),
                  );
                }

                return RefreshIndicator(
                  color: crimson,
                  onRefresh: () async {
                    ref.invalidate(warrantiesStreamProvider);
                    await ref.read(warrantiesStreamProvider.future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    itemCount: items.length,
                    itemBuilder: (_, index) => WarrantyListCard(item: items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterPill extends StatelessWidget {
  final String label;
  final Color? dotColor;
  final bool selected;
  final VoidCallback onTap;

  const _StatusFilterPill({
    required this.label,
    this.dotColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Material(
      color: selected ? onSurface : surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? onSurface : hairline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? surface : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crimson = AppTheme.crimsonOf(context);
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Material(
      color: selected
          ? (isDark
              ? AppTheme.brandCrimsonSoftDark
              : AppTheme.brandCrimsonSoftLight)
          : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? crimson.withValues(alpha: 0.45) : hairline,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? crimson : muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortOptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _SortOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? accentColor : hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? accentColor : muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 20, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultEmptyState extends StatelessWidget {
  final bool hasActiveFilter;
  final VoidCallback onClearFilters;
  final VoidCallback onScan;

  const _VaultEmptyState({
    required this.hasActiveFilter,
    required this.onClearFilters,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedTextOf(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurfaceOf(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: hasActiveFilter
                  ? Icon(Icons.search_off_rounded, size: 32, color: muted)
                  : const VarantiMark(size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              hasActiveFilter
                  ? 'No matching warranties'
                  : 'No warranties saved yet',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              hasActiveFilter
                  ? 'Try another keyword or reset your filters to view all items.'
                  : 'Tap Scan below to capture your first receipt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (hasActiveFilter)
              OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear Filters'),
                onPressed: onClearFilters,
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Scan First Receipt'),
                onPressed: onScan,
              ),
          ],
        ),
      ),
    );
  }
}
