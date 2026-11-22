import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/warranty_model.dart';

/// Visual Graph 1: Minimalist Warranty Coverage Donut Ring showing Active,
/// Expiring Soon, and Expired proportions alongside total protected value.
class WarrantyCoverageDonutCard extends StatelessWidget {
  final List<WarrantyModel> warranties;
  final void Function(String? statusFilter)? onStatusTap;

  const WarrantyCoverageDonutCard({
    super.key,
    required this.warranties,
    this.onStatusTap,
  });

  String _formatProtectedValue(List<WarrantyModel> list) {
    final priced = list.where((w) => w.pricePaid != null && w.pricePaid! > 0).toList();
    if (priced.isEmpty) return '--';
    final currencies = priced.map((w) => w.currency).toSet();
    final total = priced.fold<double>(0, (sum, w) => sum + (w.pricePaid ?? 0));
    final formatted = NumberFormat.compact().format(total);
    final prefix = currencies.length == 1 ? '${currencies.first} ' : '';
    return '$prefix$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);

    final activeCount = warranties.where((w) => w.status == 'active').length;
    final expiringCount = warranties.where((w) => w.status == 'expiring_soon').length;
    final expiredCount = warranties.where((w) => w.status == 'expired').length;
    final total = warranties.length;
    final protectedValue = _formatProtectedValue(warranties);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'COVERAGE OVERVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: muted,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: ShapeDecoration(
                  color: subtle,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 13, color: muted),
                    const SizedBox(width: 5),
                    Text(
                      'Value $protectedValue',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Thin Custom-Painted Coverage Ring
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(116, 116),
                      painter: _CoverageRingPainter(
                        active: activeCount,
                        expiring: expiringCount,
                        expired: expiredCount,
                        trackColor: subtle,
                        activeColor: AppTheme.statusActive,
                        expiringColor: AppTheme.statusExpiringSoon,
                        expiredColor: AppTheme.crimsonOf(context),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          total == 1 ? 'Item' : 'Items',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Clean Tappable Legend Rows
              Expanded(
                child: Column(
                  children: [
                    _LegendRow(
                      label: 'Active',
                      count: activeCount,
                      color: AppTheme.statusActive,
                      onTap: onStatusTap == null ? null : () => onStatusTap!('active'),
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      label: 'Expiring Soon',
                      count: expiringCount,
                      color: AppTheme.statusExpiringSoon,
                      onTap: onStatusTap == null
                          ? null
                          : () => onStatusTap!('expiring_soon'),
                    ),
                    const SizedBox(height: 8),
                    _LegendRow(
                      label: 'Expired',
                      count: expiredCount,
                      color: AppTheme.crimsonOf(context),
                      onTap: onStatusTap == null ? null : () => onStatusTap!('expired'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _LegendRow({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);

    return Material(
      color: subtle.withValues(alpha: 0.65),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverageRingPainter extends CustomPainter {
  final int active;
  final int expiring;
  final int expired;
  final Color trackColor;
  final Color activeColor;
  final Color expiringColor;
  final Color expiredColor;

  const _CoverageRingPainter({
    required this.active,
    required this.expiring,
    required this.expired,
    required this.trackColor,
    required this.activeColor,
    required this.expiringColor,
    required this.expiredColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    final total = active + expiring + expired;
    if (total == 0) return;

    final segments = <(int, Color)>[
      (active, activeColor),
      (expiring, expiringColor),
      (expired, expiredColor),
    ].where((s) => s.$1 > 0).toList();

    final gapRadians = segments.length > 1 ? 0.08 : 0.0;
    final totalSweep = (math.pi * 2) - (gapRadians * segments.length);
    double startAngle = -math.pi / 2;

    for (final seg in segments) {
      final sweep = totalSweep * (seg.$1 / total);
      final paint = Paint()
        ..color = seg.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, math.max(sweep, 0.04), false, paint);
      startAngle += sweep + gapRadians;
    }
  }

  @override
  bool shouldRepaint(covariant _CoverageRingPainter oldDelegate) {
    return oldDelegate.active != active ||
        oldDelegate.expiring != expiring ||
        oldDelegate.expired != expired ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Visual Graph 2: Toggleable 6-Month Upcoming Expirations Bar Chart and
/// Category Distribution Horizontal Bars.
class WarrantyTrendsChartCard extends StatefulWidget {
  final List<WarrantyModel> warranties;

  const WarrantyTrendsChartCard({super.key, required this.warranties});

  @override
  State<WarrantyTrendsChartCard> createState() => _WarrantyTrendsChartCardState();
}

class _WarrantyTrendsChartCardState extends State<WarrantyTrendsChartCard> {
  bool _showCategories = false;

  List<({String label, int count})> _buildSixMonthBuckets() {
    final now = DateTime.now();
    final buckets = <({String label, int count})>[];
    for (int i = 0; i < 6; i++) {
      final monthDate = DateTime(now.year, now.month + i, 1);
      final count = widget.warranties.where((w) {
        return w.warrantyExpirationDate.year == monthDate.year &&
            w.warrantyExpirationDate.month == monthDate.month;
      }).length;
      buckets.add((label: DateFormat.MMM().format(monthDate), count: count));
    }
    return buckets;
  }

  List<MapEntry<String, int>> _buildCategoryCounts() {
    final counts = <String, int>{};
    for (final w in widget.warranties) {
      counts[w.category] = (counts[w.category] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final crimson = AppTheme.crimsonOf(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _showCategories ? 'BY CATEGORY' : 'NEXT 6 MONTHS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: muted,
                  ),
                ),
              ),
              // Minimal Segmented Pill Toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: subtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniTabPill(
                      label: 'Timeline',
                      selected: !_showCategories,
                      onTap: () => setState(() => _showCategories = false),
                    ),
                    _MiniTabPill(
                      label: 'Categories',
                      selected: _showCategories,
                      onTap: () => setState(() => _showCategories = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_showCategories)
            _buildCategoryBars(
              _buildCategoryCounts(),
              crimson: crimson,
              onSurface: onSurface,
              subtle: subtle,
              muted: muted,
            )
          else
            _buildTimelineBars(
              _buildSixMonthBuckets(),
              crimson: crimson,
              onSurface: onSurface,
              subtle: subtle,
              muted: muted,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineBars(
    List<({String label, int count})> buckets, {
    required Color crimson,
    required Color onSurface,
    required Color subtle,
    required Color muted,
  }) {
    final maxCount = buckets.fold<int>(0, (m, b) => math.max(m, b.count));
    final firstUrgentIndex = buckets.indexWhere((b) => b.count > 0);

    if (maxCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.statusActive),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No warranties expiring in the next 6 months.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(buckets.length, (i) {
          final bucket = buckets[i];
          final fraction = maxCount == 0 ? 0.0 : (bucket.count / maxCount);
          final isUrgent = i == firstUrgentIndex;
          final barHeight = bucket.count == 0 ? 8.0 : math.max(18.0, fraction * 74.0);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    bucket.count > 0 ? '${bucket.count}' : '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isUrgent ? crimson : onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height: barHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bucket.count == 0
                          ? subtle
                          : isUrgent
                              ? crimson
                              : onSurface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bucket.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w500,
                      color: isUrgent ? onSurface : muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCategoryBars(
    List<MapEntry<String, int>> entries, {
    required Color crimson,
    required Color onSurface,
    required Color subtle,
    required Color muted,
  }) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          'Add receipts to see your category breakdown.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
      );
    }

    final topCount = entries.first.value;
    final visible = entries.take(5).toList();

    return Column(
      children: List.generate(visible.length, (index) {
        final entry = visible[index];
        final ratio = topCount == 0 ? 0.0 : entry.value / topCount;
        final isTop = index == 0;

        return Padding(
          padding: EdgeInsets.only(bottom: index == visible.length - 1 ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isTop ? crimson : onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 7,
                  child: Stack(
                    children: [
                      Container(color: subtle),
                      FractionallySizedBox(
                        widthFactor: ratio.clamp(0.08, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isTop
                                ? crimson
                                : onSurface.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _MiniTabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniTabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = AppTheme.mutedTextOf(context);
    final hairline = AppTheme.hairlineOf(context);

    return Material(
      color: selected ? surface : Colors.transparent,
      shape: StadiumBorder(
        side: selected ? BorderSide(color: hairline) : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? onSurface : muted,
            ),
          ),
        ),
      ),
    );
  }
}
