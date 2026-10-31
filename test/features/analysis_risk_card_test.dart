import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/analysis/data/datasources/analysis_remote_data_source.dart';
import 'package:arah/features/analysis/data/repositories/analysis_repository_impl.dart';
import 'package:arah/features/analysis/domain/usecases/get_risk_analysis.dart';
import 'package:arah/features/analysis/presentation/bloc/analysis_cubit.dart';
import 'package:arah/features/analysis/presentation/pages/analysis_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => PrivacyCubit()),
          BlocProvider(
            create: (_) => AnalysisCubit(GetRiskAnalysis(AnalysisRepositoryImpl(AnalysisFixtureDataSource())))..load(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AnalysisPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('beta: tiga kotak sama tinggi dengan label pendek', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('beta-tiles')), findsOneWidget);
    final tiles = find.descendant(of: find.byKey(const ValueKey('beta-tiles')), matching: find.byType(StatTile));
    final heights = {for (final e in tiles.evaluate()) (e.renderObject! as RenderBox).size.height};
    expect(tiles, findsNWidgets(3));
    expect(heights, hasLength(1));
  });

  testWidgets('beta: teks diperbesar → daftar baris tanpa overflow', (tester) async {
    await pump(tester, textScale: 1.5);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('beta-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('beta-tiles')), findsNothing);
    expect(find.text('0,18'), findsOneWidget);
  });
}
