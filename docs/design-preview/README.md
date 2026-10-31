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

Perubahan desain hanya menyentuh shell navigasi, tema, komponen kartu/menu, Beranda, Lainnya, dan daftar Kalkulator. Lebar konten kartu juga diseragamkan melalui `PageBody`. Layar fitur lain mendapat tema bersama; susunan form dan logika bisnisnya dipertahankan. Endpoint, parsing JSON, model, repository, autentikasi, dan respons backend tidak diubah dalam pekerjaan ini. Perubahan lokal yang telah ada sebelumnya tetap dipertahankan.

## Cakupan preview

Lima tab utama; posisi, kinerja dan riwayat portofolio; riwayat AI; aset, utang, target dan riwayat kekayaan; Watchlist; DCA beserta riwayat dan simulasi; Dividen mendatang dan diterima; Jurnal; Analisis risiko, korelasi dan stress test; Surat investor; Pengaturan; Panduan; serta tujuh alat Kalkulator. Termasuk contoh tablet dan menu dengan teks 200%.

Screenshot menunjukkan viewport awal tiap layar; bagian bawah tetap dapat digulir dalam aplikasi. Dialog tambah/ubah/hapus tidak seluruhnya diekspor. Font preview dimuat dari Flutter SDK; hasil perangkat dapat sedikit berbeda.

## Menghasilkan ulang

```sh
flutter test test/design_preview_test.dart --dart-define=EXPORT_PREVIEWS=true
flutter analyze
flutter test
```

Tes preview memeriksa navigasi kartu ke rute yang benar, seluruh layar tanpa exception layout, navigasi tablet, dan menu dengan teks besar. Uji tersebut memakai fixture dan layanan push pengganti. Backend produksi serta perangkat fisik tidak diuji oleh preview ini.
