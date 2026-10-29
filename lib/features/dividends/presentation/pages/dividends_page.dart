import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/dividends/presentation/bloc/dividends_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S11 — Dividen: Mendatang / Diterima + total diterima tahun ini. Tambah & ubah masih lewat web.
class DividendsPage extends StatelessWidget {
  const DividendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DividendsCubit>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dividen'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mendatang'),
              Tab(text: 'Diterima'),
            ],
          ),
        ),
        body: BlocBuilder<DividendsCubit, ViewState<List<Dividend>>>(
          builder: (context, state) => ViewStateBuilder<List<Dividend>>(
            state: state,
            onRetry: cubit.load,
            builder: (context, items) {
              final now = DateTime.now();
              final paid = items.where((d) => d.isPaid(now)).toList();
              final upcoming = items.where((d) => !d.isPaid(now)).toList();
              final thisYear = paid
                  .where((d) => d.paymentDate!.year == now.year)
                  .fold<double>(0, (sum, d) => sum + (d.received?.amount ?? 0));
              return TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: cubit.load,
                    child: _DividendList(items: upcoming, empty: 'Belum ada jadwal dividen'),
                  ),
                  RefreshIndicator(
                    onRefresh: cubit.load,
                    child: _DividendList(
                      items: paid,
                      empty: 'Belum ada dividen diterima',
                      header: AppCard(
                        child: InfoRow(
                          label: 'Diterima tahun ${now.year}',
                          value: AmountText(Money.idr(thisYear)),
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
    );
  }
}

class _DividendList extends StatelessWidget {
  const _DividendList({required this.items, required this.empty, this.header});
  final List<Dividend> items;
  final String empty;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    // Tanggal kosong ditulis apa adanya, bukan diisi perkiraan.
    String date(DateTime? d) => d == null ? 'Belum ditentukan' : Fmt.date(d);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        if (header != null) PageBody(child: header!),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(empty, textAlign: TextAlign.center),
          ),
        for (final d in items)
          ListTile(
            title: Text('${d.symbol} · ${Fmt.number(d.dps)} per saham'),
            subtitle: Text('Ex-date: ${date(d.exDate)} · Bayar: ${date(d.paymentDate)}'),
            trailing: d.received == null ? null : AmountText(d.received),
          ),
      ],
    );
  }
}
