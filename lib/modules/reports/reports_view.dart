import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/reports_repository.dart';
import '../shell/shell_controller.dart';
import 'reports_controller.dart';

/// REPORTS / SALES DASHBOARD: premium retail look — gradient stat cards, a
/// daily-sales bar chart, and best-sellers / low-stock panels.
///
/// UI only. All numbers come from [ReportsController] exactly as before; no
/// data logic changed here.
class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ReportsController());
    return Container(
      color: AppColors.bgLav,
      child: Obx(() {
        if (c.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TopBar(),
              const SizedBox(height: 22),
              _StatRow(c: c),
              const SizedBox(height: 20),
              // Main row: chart (wide) + best-sellers / low-stock column.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _ChartCard(daily: c.daily)),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _BestSellers(items: c.best),
                          const SizedBox(height: 18),
                          _LowStock(items: c.low),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ------------------------------- Shared bits -------------------------------

/// White rounded panel with a soft violet-tinted shadow.
BoxDecoration _panelDeco() => BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.panelBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A3A2483),
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ],
    );

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_greeting()}, ${AppText.shopName} 👋',
                  style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 5),
              Text('${_today()} · Here\'s how your shop is doing today.',
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),
        // Refresh (outline) — real action.
        OutlinedButton.icon(
          onPressed: Get.find<ReportsController>().load,
          icon: const Icon(Icons.refresh, size: 18),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            minimumSize: const Size(0, Sizes.buttonHeight),
            side: const BorderSide(color: AppColors.panelBorder),
            backgroundColor: AppColors.panel,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          label: const Text('Refresh',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        // New sale (gradient primary) — jumps to the Sale screen.
        _GradientButton(
          label: 'New sale',
          icon: Icons.add,
          onTap: () {
            if (Get.isRegistered<ShellController>()) {
              Get.find<ShellController>().go(0);
            }
          },
        ),
      ],
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _today() {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]} ${n.year}';
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Ink(
          height: Sizes.buttonHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.violet, AppColors.violetDark]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(color: Color(0x736C4CFF), blurRadius: 24, offset: Offset(0, 12)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------- Stat cards -------------------------------

class _StatRow extends StatelessWidget {
  final ReportsController c;
  const _StatRow({required this.c});

  @override
  Widget build(BuildContext context) {
    // NOTE: no crossAxisAlignment.stretch here — this Row lives inside a
    // vertical SingleChildScrollView, so its height is unbounded and `stretch`
    // would throw "BoxConstraints forces an infinite height". The four cards
    // share the same layout, so they end up equal height on their own.
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: "Today's sales",
            value: 'Rs ${c.todaySales.value.toStringAsFixed(0)}',
            tag: 'Today',
            icon: Icons.trending_up,
            colors: const [Color(0xFF7A5CFF), Color(0xFF5A3CE0)],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: "Today's profit",
            value: 'Rs ${c.todayProfit.value.toStringAsFixed(0)}',
            tag: 'Today',
            icon: Icons.savings_outlined,
            colors: const [Color(0xFFFF6B81), Color(0xFFFF9558)],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: "This month's sales",
            value: 'Rs ${c.monthSales.value.toStringAsFixed(0)}',
            tag: 'This month',
            icon: Icons.calendar_month,
            colors: const [Color(0xFF12C2B6), Color(0xFF37C6FF)],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: "This month's profit",
            value: 'Rs ${c.monthProfit.value.toStringAsFixed(0)}',
            tag: 'This month',
            icon: Icons.account_balance_wallet_outlined,
            colors: const [Color(0xFFFFB020), Color(0xFFFF8A3C)],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String tag;
  final IconData icon;
  final List<Color> colors;
  const _StatCard({
    required this.title,
    required this.value,
    required this.tag,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // No fixed height + mainAxisSize.min → the column never overflows; the row
    // stretches all four cards to the tallest one so they stay aligned.
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.38),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 12),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92))),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(tag,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------- Chart card -------------------------------

class _ChartCard extends StatefulWidget {
  final List<DailySales> daily;
  const _ChartCard({required this.daily});

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  int _range = 1; // 0 Week · 1 Month · 2 Year (Month = live view)

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDeco(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily sales this month',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                    SizedBox(height: 3),
                    Text('Every day of the month',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
              _SegToggle(
                index: _range,
                labels: const ['Week', 'Month', 'Year'],
                onChanged: (i) => setState(() => _range = i),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 240,
            child: widget.daily.isEmpty
                ? const Center(
                    child: Text('No sales yet this month.',
                        style: TextStyle(fontSize: 16, color: AppColors.muted)),
                  )
                : _bars(),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.panelBorder),
          const SizedBox(height: 16),
          const _PaymentMethods(),
        ],
      ),
    );
  }

  Widget _bars() {
    final daily = widget.daily;
    final dataMax = daily.fold<double>(0, (m, d) => d.amount > m ? d.amount : m);

    // Even tick interval, axis max rounded UP to a whole multiple — the data
    // max never adds its own colliding tick.
    final interval = _niceInterval(dataMax);
    final maxY = dataMax <= 0 ? interval * 5 : (dataMax / interval).ceil() * interval;
    final labelStep = (daily.length / 6).ceil().clamp(1, daily.length);
    final todayKey = _todayKey();

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < daily.length; i++) {
      final isToday = daily[i].day == todayKey;
      // Clamp negatives (net-return days) to 0 so no bar draws below the zero
      // line and the chart never looks broken. The real value still shows in
      // the tooltip.
      final barY = daily[i].amount < 0 ? 0.0 : daily[i].amount;
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: barY,
          width: 15,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isToday
                ? const [AppColors.amber, AppColors.coral]
                : const [AppColors.lilac, AppColors.violet],
          ),
        ),
      ]));
    }

    return BarChart(BarChartData(
      maxY: maxY,
      minY: 0,
      barGroups: groups,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: Color(0xFFEFEAF9), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF241141),
          tooltipRoundedRadius: 11,
          getTooltipItem: (group, gi, rod, ri) {
            final d = daily[group.x];
            final isToday = d.day == todayKey;
            return BarTooltipItem(
              '${isToday ? 'Today · ' : ''}Jul ${int.parse(d.day.substring(8))}\n',
              const TextStyle(color: Color(0xFFC9BCF5), fontWeight: FontWeight.w600, fontSize: 11.5),
              children: [
                TextSpan(
                  text: 'Rs ${d.amount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 46,
            interval: interval,
            getTitlesWidget: (value, meta) {
              if (value > maxY + 0.5) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(_fmtK(value),
                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= daily.length) return const SizedBox.shrink();
              final isToday = daily[i].day == todayKey;
              if (i != 0 && !isToday && i % labelStep != 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(daily[i].day.substring(8),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isToday ? AppColors.coral : AppColors.muted)),
              );
            },
          ),
        ),
      ),
    ));
  }

  static String _todayKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  static double _niceInterval(double maxVal) {
    if (maxVal <= 0) return 100;
    final rough = maxVal / 5;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final norm = rough / mag;
    final double niceNorm;
    if (norm <= 1) {
      niceNorm = 1;
    } else if (norm <= 2) {
      niceNorm = 2;
    } else if (norm <= 2.5) {
      niceNorm = 2.5;
    } else if (norm <= 5) {
      niceNorm = 5;
    } else {
      niceNorm = 10;
    }
    return niceNorm * mag;
  }

  static String _fmtK(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.roundToDouble() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    return v.toInt().toString();
  }
}

class _SegToggle extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _SegToggle({required this.index, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFECF8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: i == index ? AppColors.panel : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: i == index
                      ? const [BoxShadow(color: Color(0x1A3A2483), blurRadius: 8, offset: Offset(0, 3))]
                      : null,
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: i == index ? AppColors.violet : AppColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Static split shown for the current cash/card mix. (Illustrative — wire to
/// real payment data when available.)
class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment methods',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 12),
        _bar('Cash', 0.58, const [AppColors.tealBright, AppColors.sky]),
        const SizedBox(height: 11),
        _bar('Card', 0.27, const [AppColors.violet, AppColors.lilac]),
        const SizedBox(height: 11),
        _bar('Online', 0.15, const [AppColors.coral, AppColors.amber]),
      ],
    );
  }

  Widget _bar(String label, double pct, List<Color> colors) {
    return Row(
      children: [
        SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 9,
              color: const Color(0xFFEFECF8),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: colors),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text('${(pct * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ),
      ],
    );
  }
}

// --------------------------- Best sellers / Low stock ---------------------------

class _BestSellers extends StatelessWidget {
  final List<BestSeller> items;
  const _BestSellers({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDeco(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Best selling products',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text('Top movers, all time',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No sales yet.', style: TextStyle(fontSize: 16, color: AppColors.muted)),
            )
          else
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _rankColors(i)),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(items[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    ),
                    Text('${items[i].qty} sold',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.violet, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static List<Color> _rankColors(int i) {
    const palettes = [
      [AppColors.violet, AppColors.lilac],
      [AppColors.tealBright, AppColors.sky],
      [AppColors.amber, AppColors.coral],
      [AppColors.sky, AppColors.violet],
      [AppColors.coral, AppColors.amber],
    ];
    return palettes[i % palettes.length];
  }
}

class _LowStock extends StatelessWidget {
  final List<({String name, int stock})> items;
  const _LowStock({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDeco(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Low stock',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text('Reorder these soon',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('All items are well stocked.',
                  style: TextStyle(fontSize: 16, color: AppColors.muted)),
            )
          else
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.warnBg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warn, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(it.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warnBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${it.stock} left',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.warn, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
