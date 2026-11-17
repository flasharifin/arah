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
  pw.ImageProvider? logo,
}) {
  final doc = pw.Document(
    title: 'Laporan Kekayaan Arah',
    theme: font == null ? null : pw.ThemeData.withFont(base: font, bold: bold ?? font),
  );
  // Warna merek app (AppColors.primary / primarySoft).
  const brand = PdfColor.fromInt(0xFF173F35);
  const brandSoft = PdfColor.fromInt(0xFFE4F0E6);
  const muted = PdfColors.grey700;
  final head = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: brand);
  const cell = pw.TextStyle(fontSize: 8);
  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Row(
      children: [
        pw.Container(width: 3, height: 12, color: brand),
        pw.SizedBox(width: 6),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brand),
        ),
      ],
    ),
  );
  pw.Widget stat(String label, Money value, {bool strong = false}) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: strong ? brand : brandSoft, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: strong ? brandSoft : muted)),
          pw.SizedBox(height: 4),
          pw.Text(
            Fmt.money(value),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: strong ? PdfColors.white : brand),
          ),
        ],
      ),
    ),
  );
  pw.Widget table(List<String> headers, List<List<String>> rows, {Set<int> left = const {0}}) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: head,
        cellStyle: cell,
        headerDecoration: const pw.BoxDecoration(color: brandSoft),
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
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5, color: muted)),
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
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 24),
      header: (c) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: brand, width: 1.5)),
        ),
        child: pw.Row(
          children: [
            if (logo != null) ...[
              pw.ClipRRect(horizontalRadius: 6, verticalRadius: 6, child: pw.Image(logo, width: 28, height: 28)),
              pw.SizedBox(width: 8),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Arah',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: brand),
                ),
                pw.Text('Laporan Kekayaan', style: const pw.TextStyle(fontSize: 8, color: muted)),
              ],
            ),
            pw.Spacer(),
            pw.Text(
              DateFormat('d MMMM yyyy, HH.mm', 'id').format(now),
              style: const pw.TextStyle(fontSize: 8, color: muted),
            ),
          ],
        ),
      ),
      footer: (c) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Rahasia · dokumen pribadi dari aplikasi Arah',
              style: const pw.TextStyle(fontSize: 7, color: muted),
            ),
            pw.Text(
              'Halaman ${c.pageNumber} dari ${c.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: muted),
            ),
          ],
        ),
      ),
      build: (c) => [
        pw.Text('Ringkasan kekayaan', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        if (p?.priceAsOf != null || rate != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            [
              if (p?.priceAsOf != null) 'Harga per ${Fmt.dateTime(p!.priceAsOf)}',
              if (rate != null) 'kurs US\$ 1 = ${Fmt.money(Money.idr(rate))}',
            ].join(' · '),
            style: const pw.TextStyle(fontSize: 8.5, color: muted),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            stat('Total aset', netWorth.totalAssets),
            pw.SizedBox(width: 8),
            stat('Total utang', netWorth.totalLiabilities),
            pw.SizedBox(width: 8),
            stat('Kekayaan bersih', netWorth.netWorth, strong: true),
          ],
        ),

        section('Portofolio'),
        if (p == null || p.positions.isEmpty)
          note(p == null ? 'Data portofolio belum dimuat di app.' : 'Belum ada posisi.')
        else ...[
          for (final currency in p.currencies) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
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
    final logo = pw.MemoryImage((await rootBundle.load('assets/images/arah-mark.png')).buffer.asUint8List());
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'));
    final now = DateTime.now();
    final bytes = await buildWealthReport(
      netWorth: netWorth,
      portfolio: portfolio,
      now: now,
      font: font,
      bold: bold,
      logo: logo,
    );
    await Printing.sharePdf(bytes: bytes, filename: 'arah-kekayaan-${DateFormat('yyyy-MM-dd').format(now)}.pdf');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
  }
}
