import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// S16 — Panduan: cara pakai singkat + istilah. Isi statis, mengikuti perilaku server (cron, rumus).
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _start = [
    'Catat pembelian di Portofolio (dari detail posisi atau Watchlist). Lot IDX = 100 lembar; US & kripto dalam unit.',
    'Tambahkan aset lain (kas, emas, properti) dan utang di Kekayaan supaya kekayaan bersih lengkap.',
    'Harga diperbarui saat aplikasi dibuka; PnL harian dicatat otomatis setiap malam (00.00 WIB).',
    'Grafik Kinerja butuh beberapa hari catatan PnL — wajar kalau awalnya kosong.',
    'Data sama dengan web: perubahan di aplikasi tampil di web setelah halaman dimuat ulang, dan sebaliknya.',
    'Sembunyikan nominal dari menu Lainnya saat membuka aplikasi di tempat umum.',
  ];

  static const _terms = <(String, String)>[
    ('Kekayaan bersih', 'Total aset (portofolio + aset manual) dikurangi total utang, dalam rupiah.'),
    (
      'Unrealized PnL',
      'Untung/rugi posisi yang masih dipegang: (harga terakhir − harga rata-rata) × jumlah. Belum terkunci sampai dijual.',
    ),
    ('Realized PnL', 'Untung/rugi yang sudah terkunci saat menjual: hasil jual dikurangi modal posisi yang dijual.'),
    ('Harga rata-rata', 'Rata-rata harga beli tertimbang jumlah. Pembelian tambahan menghitung ulang rata-rata ini.'),
    (
      'Return kumulatif (TWR)',
      'Return harian yang dimajemukkan. Tidak terpengaruh setoran atau penarikan modal, jadi adil dibanding IHSG & S&P 500.',
    ),
    ('Benchmark', 'Pembanding kinerja: IHSG untuk saham Indonesia, S&P 500 untuk saham AS.'),
    ('Drawdown', 'Penurunan nilai dari titik tertinggi sebelumnya, dalam persen.'),
    ('Volatilitas', 'Seberapa besar naik-turun nilai harian. Makin tinggi, makin besar ayunan nilai portofolio.'),
    (
      'Korelasi',
      'Seberapa searah dua aset bergerak (−1 sampai 1). Mendekati 1 = bergerak bersama, diversifikasi lemah.',
    ),
    ('Stress test', 'Simulasi dampak skenario penurunan pasar ke portofolio. Hasilnya estimasi, bukan ramalan.'),
    ('DCA', 'Dollar cost averaging: membeli rutin dengan nominal tetap, tanpa menebak waktu terbaik.'),
    ('BEP', 'Break-even price: harga jual minimal agar posisi impas setelah biaya transaksi.'),
    ('Yield on cost (YOC)', 'Dividen per tahun dibagi harga rata-rata beli, dalam persen.'),
    ('Snapshot', 'Catatan kekayaan bersih pada satu tanggal, untuk melihat tren dari waktu ke waktu.'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Panduan')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          PageBody(
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Mulai', style: text.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  for (final (i, s) in _start.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text('${i + 1}. $s', style: text.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PageBody(child: Text('Istilah', style: text.titleSmall)),
          for (final (term, meaning) in _terms)
            PageBody(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(term),
                childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
                expandedAlignment: Alignment.centerLeft,
                children: [Text(meaning, style: text.bodyMedium)],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          PageBody(
            child: Text('Angka di aplikasi adalah catatan dan estimasi, bukan saran investasi.', style: text.bodySmall),
          ),
        ],
      ),
    );
  }
}
