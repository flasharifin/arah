# Preview desain Arah

Buka `index.html` di browser untuk galeri screenshot. Klik gambar untuk ukuran penuh. Ini tangkapan layar Flutter asli, bukan gambar konsep. Data adalah fixture; tanggal mengikuti saat tes dijalankan. Galeri tidak mengakses backend dan bukan aplikasi transaksi interaktif.

## Hasil analisis

- Arsitektur sudah dibagi per fitur menjadi `data`, `domain`, dan `presentation`, dengan Bloc/Cubit untuk state. Struktur ini dipertahankan.
- Komponen bersama (`HeroCard`, `AppCard`, `AmountText`, `MenuTile`, `PageBody`) sudah menjadi fondasi yang baik. Desain diperbarui di lapisan ini agar konsisten antarfitur.
- Nilai utama, nilai pendukung, dan aksi perlu lebih mudah dibedakan. Hero hijau bergradasi, latar netral, serta kelompok akses cepat memberi urutan baca yang lebih jelas.
- Menu pendukung memakai kartu berikon dan deskripsi singkat, dikelompokkan berdasarkan kebutuhan. Kalkulator menggunakan komponen kartu yang sama.
- Lima tab tetap tersedia di ponsel. Lebar mulai 840 px menggunakan navigasi samping. Konten tetap dibatasi agar baris data tidak terlalu panjang.
- Grid menu mengikuti ruang dan ukuran teks; pada teks besar berpindah ke satu kolom. Nilai uang tetap memakai komponen privasi dan format mata uang yang sudah ada.

## Batas perubahan

Desain mengikuti artifact "Arah — redesign layar" (31 Okt 2026): font Plus Jakarta Sans (aset lokal, OFL), latar hijau sangat muda, kartu putih modular, hero hijau hutan datar, aksen lime, angka tabular. Navigasi bawah: Beranda · Portofolio · **Catat** (tombol tengah → sheet semua pencatatan) · Kekayaan · Lainnya; AI Chat dibuka dari tombol "Tanya AI" di header dan menu Lainnya (rutenya tetap cabang shell supaya percakapan bertahan). Layar di artifact (Beranda, Portofolio · Posisi/Kinerja, Catat, Kekayaan bertumpuk tanpa tab, Lainnya dengan pencarian, Analisis) disusun ulang; layar lain mendapat tema, tab segmen, chip, dan komponen bersama (`ModuleCard`, `StatTile`, `SegmentedTabBar`, `AskAiButton`). Endpoint, parsing JSON, model, repository, autentikasi, dan respons backend tidak diubah; Beranda memakai `totalDailyChangeIDR`/`totalDailyChangePct` yang sudah ada di `/api/summary`.

## Cakupan preview

Lima tab utama dan sheet Catat; posisi, kinerja dan riwayat portofolio; riwayat AI; target dan riwayat kekayaan; Watchlist; DCA beserta riwayat dan simulasi; Dividen mendatang dan diterima; Jurnal; Analisis risiko, korelasi dan stress test; Surat investor; Pengaturan; Panduan; serta tujuh alat Kalkulator. Termasuk contoh tablet dan menu dengan teks 200%.

Screenshot menunjukkan viewport awal tiap layar; bagian bawah tetap dapat digulir dalam aplikasi. Dialog tambah/ubah/hapus tidak seluruhnya diekspor. Font preview dimuat dari Flutter SDK; hasil perangkat dapat sedikit berbeda.

## Menghasilkan ulang

```sh
flutter test test/design_preview_test.dart --dart-define=EXPORT_PREVIEWS=true
flutter analyze
flutter test
```

Tes preview memeriksa navigasi kartu ke rute yang benar, seluruh layar tanpa exception layout, navigasi tablet, dan menu dengan teks besar. Uji tersebut memakai fixture dan layanan push pengganti. Backend produksi serta perangkat fisik tidak diuji oleh preview ini.
