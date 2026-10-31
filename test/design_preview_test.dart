import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arah/app/app.dart';
import 'package:arah/app/di.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/features/calculator/presentation/pages/calculator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

class _PreviewPush implements PushNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermissionAndRegister() async {}
  @override
  Future<void> unregisterDevice() async {}
  @override
  Stream<String> get openedRoutes => const Stream.empty();
}

void main() {
  const export = bool.fromEnvironment('EXPORT_PREVIEWS');
  const boundaryKey = ValueKey('preview');
  setUpAll(() async {
    await initializeDateFormatting('id');
    FlutterSecureStorage.setMockInitialValues({});
    configureDependencies(useFixtures: true);
    sl
      ..unregister<PushNotificationService>()
      ..registerSingleton<PushNotificationService>(_PreviewPush());
    if (export) {
      final configFile = File('.dart_tool/package_config.json');
      final config = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final packages = config['packages'] as List<dynamic>;
      final flutter = packages.cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == 'flutter');
      final root = configFile.absolute.uri.resolve('${flutter['rootUri']}/').resolve('../../');
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final font = File.fromUri(root.resolve('bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'));
      final bytes = ByteData.sublistView(await font.readAsBytes());
      for (final family in ['Roboto', 'Ahem']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
  });
  tearDownAll(() => sl.reset());

  testWidgets('semua menu pascalogin, subtab, navigasi tablet, dan teks besar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const RepaintBoundary(key: boundaryKey, child: ArahApp()));
    if (export) {
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/arah-logo.png'),
          tester.element(find.byType(MaterialApp)),
        ),
      );
    }
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'demo@arah.id');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      if (!export) return;
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/design-preview/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> open(String route, String name) async {
      router.go(route);
      await tester.pumpAndSettle();
      await capture(name);
    }

    await capture('01-beranda');
    await tester.tap(find.text('Semua menu'));
    await tester.pumpAndSettle();
    expect(find.text('Watchlist'), findsOneWidget);
    await capture('05-semua-menu');
    // Menu benar-benar dapat diakses dari kartu, termasuk yang perlu digulir.
    for (final entry in {
      'Watchlist': 'watchlist',
      'DCA': 'dca',
      'Dividen': 'dividends',
      'Analisis risiko': 'analysis',
      'Kalkulator': 'calculator',
      'Jurnal': 'journal',
      'Surat investor': 'investor-letter',
      'Pengaturan': 'settings',
      'Panduan': 'help',
    }.entries) {
      router.go('/more');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/more/${entry.value}');
      await capture('menu-${entry.value}');
    }
    await open('/portfolio', '02-portofolio');
    for (final tab in ['Kinerja', 'Riwayat']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await capture('portofolio-${tab.toLowerCase()}');
    }
    await open('/portfolio/bbca', 'portofolio-detail');
    await open('/assistant', '03-ai-chat');
    await open('/assistant/history', 'ai-riwayat');
    await open('/wealth', '04-kekayaan');
    for (final tab in ['Utang', 'Target', 'Riwayat']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await capture('kekayaan-${tab.toLowerCase()}');
    }
    for (final tool in CalculatorTool.values) {
      await open('/more/calculator/${tool.slug}', 'kalkulator-${tool.slug}');
    }
    for (final section in {
      'analysis': ['Korelasi', 'Stress test'],
      'dca': ['Riwayat', 'Simulasi'],
      'dividends': ['Diterima'],
    }.entries) {
      router.go('/more/${section.key}');
      await tester.pumpAndSettle();
      for (final tab in section.value) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        await capture('${section.key}-${tab.toLowerCase().replaceAll(' ', '-')}');
      }
    }
    tester.view.physicalSize = const Size(1280, 900);
    await open('/home', 'tablet-beranda');
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    // Berpindah tab memulihkan subhalaman; tap tab aktif kembali ke akar.
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/more');
    expect(find.text('Semua kebutuhan, satu tempat.'), findsOneWidget);
    await capture('tablet-menu');
    tester.view.physicalSize = const Size(360, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await capture('aksesibilitas-menu');
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
