import 'dart:typed_data';

import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Satu PDF berisi ringkasan, portofolio, aset, dan utang dari data yang sudah dimuat app.
/// Angka selalu asli (mode sembunyikan nominal tidak berlaku): ini arsip pribadi.
Future<Uint8List> buildWealthReport({
  required NetWorth netWorth,
  required Portfolio? portfolio,
  required DateTime now,
  pw.Font? font,
  pw.Font? bold,
}) {
  final doc = pw.Document(
    title: 'Laporan Kekayaan Arah',
    theme: font == null ? null : pw.ThemeData.withFont(base: font, bold: bold ?? font),
  );
  final head = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
  const cell = pw.TextStyle(fontSize: 8);
  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
  );
  pw.Widget table(List<String> headers, List<List<String>> rows, {Set<int> left = const {0}}) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: head,
        cellStyle: cell,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignment: pw.Alignment.centerRight,
        cellAlignments: {for (final i in left) i: pw.Alignment.centerLeft},
        headerAlignments: {
          for (var i = 0; i < headers.length; i++)
            i: left.contains(i) ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      );
  pw.Widget note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
  );

  String original(WealthItem i) => switch (i.entry) {
    final e? when e.currency == 'GOLD' => '${Fmt.quantity(e.amount)} gram',
    final e? when e.currency == 'USD' => Fmt.money(Money.usd(e.amount)),
    _ => Fmt.money(i.value),
  };
  String assetCategory(WealthItem i) => assetCategories[i.entry?.category] ?? i.category.label;
  String debtCategory(WealthItem i) => liabilityCategories[i.entry?.category] ?? i.category.label;

  final p = portfolio;
  final rate = p?.usdToIdr;
  final total = p?.totalValueIdr ?? 0;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dokumen pribadi · dibuat dari app Arah',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text('${c.pageNumber}/${c.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
      build: (c) => [
        pw.Text('Laporan Kekayaan', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Dibuat ${DateFormat('d MMMM yyyy, HH.mm', 'id').format(now)}'
          '${p?.priceAsOf == null ? '' : ' · harga per ${Fmt.dateTime(p!.priceAsOf)}'}'
          '${rate == null ? '' : ' · kurs US\$ 1 = ${Fmt.money(Money.idr(rate))}'}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),

        section('Ringkasan'),
        table(
          ['', 'Rupiah'],
          [
            ['Total aset', Fmt.money(netWorth.totalAssets)],
            ['Total utang', Fmt.money(netWorth.totalLiabilities)],
            ['Kekayaan bersih', Fmt.money(netWorth.netWorth)],
          ],
        ),

        section('Portofolio'),
        if (p == null || p.positions.isEmpty)
          note(p == null ? 'Data portofolio belum dimuat di app.' : 'Belum ada posisi.')
        else ...[
          for (final currency in p.currencies) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
              child: pw.Text(currency == Currency.idr ? 'Rupiah' : 'Dolar AS', style: head),
            ),
            table(
              ['Kode', 'Broker', 'Jumlah', 'Rata-rata', 'Terakhir', 'Nilai', 'Untung/rugi', '%', 'Porsi'],
              [
                for (final pos in p.positions.where((x) => x.currency == currency))
                  [
                    pos.symbol,
                    pos.broker.isEmpty ? '—' : pos.broker,
                    '${Fmt.quantity(pos.quantity)} ${pos.exchange.quantityLabel}',
                    Fmt.money(pos.avgPrice),
                    Fmt.money(pos.lastPrice),
                    Fmt.money(pos.marketValue ?? pos.costBasis),
                    Fmt.money(pos.unrealizedPnl, signed: true),
                    Fmt.percent(pos.unrealizedPercent),
                    total > 0 ? Fmt.percent(p.valueIdr(pos) / total * 100, signed: false) : '—',
                  ],
                if (p.pricedTotals(currency) case final t?)
                  [
                    p.unpriced.any((x) => x.currency == currency) ? 'Total (yang ada harga)' : 'Total',
                    '',
                    '',
                    '',
                    '',
                    Fmt.money(t.value),
                    Fmt.money(t.pnl, signed: true),
                    Fmt.percent(t.percent),
                    '',
                  ],
              ],
              left: {0, 1},
            ),
          ],
          note(
            'Total gabungan ${Fmt.money(Money.idr(total))}. Porsi dihitung dalam rupiah; posisi tanpa harga '
            'terakhir memakai modal${p.unpriced.isEmpty ? '' : ' (${p.unpriced.map((x) => x.symbol).join(', ')})'}.',
          ),
        ],

        section('Aset'),
        if (netWorth.assets.isEmpty)
          note('Belum ada aset.')
        else
          table(
            ['Nama', 'Kategori', 'Nilai asal', 'Setara rupiah'],
            [
              for (final i in netWorth.assets)
                [i.isAutomatic ? '${i.name} (otomatis)' : i.name, assetCategory(i), original(i), Fmt.money(i.value)],
              ['Total', '', '', Fmt.money(netWorth.totalAssets)],
            ],
            left: {0, 1},
          ),

        section('Utang'),
        if (netWorth.liabilities.isEmpty)
          note('Tidak ada utang.')
        else
          table(
            ['Nama', 'Kategori', 'Sisa utang'],
            [
              for (final i in netWorth.liabilities) [i.name, debtCategory(i), Fmt.money(i.value)],
              ['Total', '', Fmt.money(netWorth.totalLiabilities)],
            ],
            left: {0, 1},
          ),
      ],
    ),
  );
  return doc.save();
}

/// Tombol "Unduh PDF" Kekayaan: bangun laporan lalu buka lembar bagikan HP (simpan ke Files, WhatsApp, email, …).
Future<void> shareWealthReport(BuildContext context) async {
  final netWorth = context.read<NetWorthCubit>().state.data;
  final portfolio = context.read<PortfolioBloc?>()?.state.data.data;
  final messenger = ScaffoldMessenger.of(context);
  if (netWorth == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Data Kekayaan belum dimuat. Coba lagi sebentar.')));
    return;
  }
  try {
    // Font app di-embed: font bawaan PDF tidak punya huruf seperti "−" dan "—".
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'));
    final now = DateTime.now();
    final bytes = await buildWealthReport(netWorth: netWorth, portfolio: portfolio, now: now, font: font, bold: bold);
    await Printing.sharePdf(bytes: bytes, filename: 'arah-kekayaan-${DateFormat('yyyy-MM-dd').format(now)}.pdf');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
  }
}
