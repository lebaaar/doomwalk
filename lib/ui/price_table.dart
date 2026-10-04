import 'package:flutter/material.dart';

import '../core/scroll_wallet.dart';
import '../core/units.dart';
import 'theme.dart';

/// One row of [priceRows]: from [fromM] scrolled today (to [toM], or open
/// ended when null) a metre of scrolling costs [price] metres of walking.
typedef PriceRow = ({double fromM, double? toM, double price, int stepsPer100});

/// The multiplier table for [c]: one row per price step, up to the cap,
/// with the steps 100 m of scrolling costs at [c]'s stride.
List<PriceRow> priceRows(WalletConfig c) {
  final cap = c.maxPrice < 1 ? 1.0 : c.maxPrice.floorToDouble();
  final rows = <PriceRow>[];
  for (var p = 1.0; p <= cap; p++) {
    final last = p == cap || c.priceStepM <= 0;
    final from = (p - 1) * c.priceStepM;
    rows.add((
      fromM: from,
      toM: last ? null : from + c.priceStepM,
      price: p,
      stepsPer100: c.strideM <= 0 ? 0 : (100 * p / c.strideM).ceil(),
    ));
    if (last) break;
  }
  return rows;
}

/// "Scrolled today / multiplier / 100 m of scrolling costs", with today's
/// row highlighted.
class PriceTable extends StatelessWidget {
  const PriceTable({super.key, required this.config, this.currentPrice});
  final WalletConfig config;

  /// Today's multiplier; its row is highlighted. Null highlights nothing.
  final double? currentPrice;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = context.colors;
    final rows = priceRows(config);
    String range(PriceRow r) => r.toM == null
        ? '${formatRound(r.fromM)}+'
        : '${r.fromM.round()}–${(r.toM! - 1).round()} m';
    Widget cell(String text, {TextStyle? style, TextAlign align = TextAlign.start, int flex = 1}) =>
        Expanded(flex: flex, child: Text(text, textAlign: align, style: style));
    final head = t.bodySmall?.copyWith(color: col.muted);
    return Semantics(
      label: 'Multiplier by distance scrolled today: '
          '${rows.map((r) => '${range(r)}, ${formatTimes(r.price)}, ${formatCount(r.stepsPer100)} steps per 100 m').join('; ')}',
      excludeSemantics: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            cell('Scrolled today', style: head, flex: 4),
            cell('Multiplier', style: head, flex: 3),
            cell('100 m costs', style: head, flex: 4, align: TextAlign.end),
          ]),
        ),
        for (final r in rows)
          Builder(builder: (context) {
            final now = currentPrice != null && currentPrice == r.price;
            final style = (now ? t.titleSmall : t.bodyLarge)?.merge(numeric).copyWith(
                  color: now ? col.onAccentContainer : col.text,
                );
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: now ? col.accentContainer : null,
                borderRadius: BorderRadius.circular(Radii.small),
              ),
              child: Row(children: [
                cell(range(r), style: style, flex: 4),
                cell('${formatTimes(r.price)}${r.toM == null && rows.length > 1 ? ' (max)' : ''}',
                    style: style, flex: 3),
                cell('${formatCount(r.stepsPer100)} steps', style: style, flex: 4, align: TextAlign.end),
              ]),
            );
          }),
      ]),
    );
  }
}
