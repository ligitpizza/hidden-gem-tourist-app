import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../features/gamification_journal/model/journal_entry_model.dart';
import '../../features/gamification_journal/model/user_stats_model.dart';

/// Pie chart + legend for the "Local Economy Support Tracker" breakdown.
/// Shows a locked state (rather than an empty chart) until at least one
/// journal entry has an amount logged in some category.
class EconomicImpactChart extends StatelessWidget {
  const EconomicImpactChart({super.key, required this.breakdown});

  final List<EconomicImpactSlice> breakdown;

  Color _colorFor(BuildContext context, LocalSupportOption option) {
    final colors = AppColors.of(context);
    switch (option) {
      case LocalSupportOption.foodCafe:
        return colors.primaryContainer;
      case LocalSupportOption.souvenirsHandicrafts:
        return colors.secondaryContainer;
      case LocalSupportOption.localGuideTransport:
        return colors.tertiaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return Column(
        children: [
          Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.of(context).outlineVariant, width: 8, style: BorderStyle.solid),
            ),
            child: Icon(Icons.lock_outline, size: 30, color: AppColors.of(context).outline),
          ),
          Text(
            'Log spending in a journal entry to unlock your local-economy breakdown here.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm,
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: breakdown.map((slice) {
                return PieChartSectionData(
                  value: slice.amountRM,
                  color: _colorFor(context, slice.option),
                  title: '${slice.percentageOfTotal.toStringAsFixed(0)}%',
                  radius: 46,
                  titleStyle: AppTypography.labelSm.copyWith(color: AppColors.of(context).onPrimary, fontSize: 11),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...breakdown.map((slice) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _colorFor(context, slice.option),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(slice.option.label, style: AppTypography.bodySm)),
                Text(
                  'RM ${slice.amountRM.toStringAsFixed(0)}',
                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: AppColors.of(context).onSurface),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
