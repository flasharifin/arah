# Arah — aplikasi mobile Flutter

Skeleton dari rancangan `dashboard-assets-app/doc/designapp`. Clean architecture per fitur, BLoC untuk state.

```bash
flutter run                                   # data fixture (default)
flutter run --dart-define=USE_FIXTURES=false --dart-define=API_BASE_URL=https://...
flutter test
flutter build apk --release --dart-define=USE_FIXTURES=false
```

## Struktur

```
lib/
  app/            di.dart (get_it), router.dart (go_router, 5 tab), app_shell.dart, app.dart
  core/
    domain/       Money (nominal + mata uang asal)
    error/        Failure, Result<T>, guard() (exception → Failure)
    network/      ApiClient (Dio + token + unwrap `{ data }`)
    state/        ViewState<T> (initial/loading/success/failure, data lama dipertahankan), PrivacyCubit
    format/       Fmt: Rp/US$, persen bertanda, tanggal id, `—` untuk data kosong
    theme/        token warna, spacing, radius, tipografi, ThemeData
    widgets/      komponen reusable (impor `core/widgets/widgets.dart`)
  features/<fitur>/
    domain/       entities, repositories (interface), usecases
    data/         models (fromJson), datasources (API + Fixture), repositories (impl)
    presentation/ bloc, pages, widgets
```

Aturan dependensi: `presentation → domain ← data`. Domain tidak mengimpor Flutter, Dio, atau data layer.
Antarfitur tidak saling impor; navigasi lintas fitur memakai route (contoh: detail posisi → `/assistant?symbol=BBCA&exchange=IDX`).

## Komponen reusable

| Komponen | Untuk |
|---|---|
| `ViewStateBuilder<T>` | skeleton → error/empty → konten dari `ViewState<T>` |
| `AmountText`, `PnlText` | nominal yang menghormati mode privasi; PnL selalu bertanda +/− |
| `AppCard`, `HeroCard` | kartu standar & kartu ringkasan forest |
| `SectionHeader`, `InfoRow`, `PageBody` | judul bagian, baris label–nilai, lebar maks 720 + margin 20 |
| `AppTextField`, `PasswordField`, `PrimaryButton` | form; tombol mencegah submit ganda |
| `ChoiceChipBar<T>` | filter/segmen chip |
| `MenuTile`, `MenuGroup` | daftar menu |
| `GoalProgress` | progres menuju target |
| `EmptyView`, `ErrorView`, `InlineError`, `SkeletonList` | state kosong/gagal/memuat |

## Menambah fitur (contoh: watchlist)

1. `domain/`: entity, `WatchlistRepository` (interface), use case `GetWatchlist`.
2. `data/`: `WatchlistModel.fromJson`, `WatchlistRemoteDataSource` + `Api`/`Fixture` impl, `WatchlistRepositoryImpl` memakai `guard()`.
3. `presentation/`: `WatchlistCubit extends Cubit<ViewState<Watchlist>>` (atau Bloc bila banyak event), page memakai `ViewStateBuilder`.
4. Daftarkan di `app/di.dart`, tambah route di `app/router.dart` (ganti `UpcomingFeaturePage` untuk slug tsb).
5. Tes: entity/perhitungan + bloc.

## Status

Sudah: tema, navigasi 5 tab, auth (fixture), Beranda, Portofolio (+ detail, filter, cari), AI Chat (retry idempoten, konteks aset), Kekayaan, Lainnya.
Data API nyata baru untuk portofolio (`/api/portfolio` + `/api/market`); auth mobile dan endpoint AI belum ada di backend sehingga memakai fixture.

## Firebase (project `arah-106cb`)

Package/bundle ID: `com.arkadigitalsolution.arah`. Crashlytics aktif di build non-debug; error Flutter dan async dikirim sebagai fatal.
Push (FCM + `flutter_local_notifications`, channel Android `arah_default`): izin diminta setelah login.
- App terbuka: pesan FCM ditampilkan sebagai notifikasi lokal.
- Background/tertutup: pesan dengan blok `notification` ditampilkan sistem; pesan data-only (`data.title`, `data.body`) ditampilkan oleh `firebaseMessagingBackgroundHandler`.
- Tap notifikasi membuka `data.route` (hanya rute internal, mis. `/portfolio/bbca`).

iOS belum lengkap:
1. Daftarkan app iOS `com.arkadigitalsolution.arah` di Firebase, taruh `GoogleService-Info.plist` di `ios/Runner/` dan tambahkan ke target Runner lewat Xcode.
2. Xcode → Runner → Signing & Capabilities: tambah **Push Notifications** (Background Modes → Remote notifications sudah ada di Info.plist).
3. Upload APNs Auth Key (.p8) di Firebase Console → Project settings → Cloud Messaging.
4. Untuk simbolikasi crash iOS, tambahkan Run Script Crashlytics (`flutterfire configure` bisa mengaturnya).
