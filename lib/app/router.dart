import 'dart:async';

import 'package:arah/app/app_shell.dart';
import 'package:arah/app/di.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:arah/features/assistant/presentation/bloc/conversation_history_cubit.dart';
import 'package:arah/features/assistant/presentation/pages/conversation_history_page.dart';
import 'package:arah/features/assistant/presentation/pages/chat_page.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arah/features/auth/presentation/bloc/password_reset_cubit.dart';
import 'package:arah/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:arah/features/auth/presentation/pages/login_page.dart';
import 'package:arah/features/auth/presentation/pages/splash_page.dart';
import 'package:arah/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:arah/features/dashboard/presentation/pages/home_page.dart';
import 'package:arah/features/more/presentation/pages/more_page.dart';
import 'package:arah/features/more/presentation/pages/upcoming_feature_page.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/networth/presentation/pages/net_worth_page.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/portfolio/presentation/pages/portfolio_page.dart';
import 'package:arah/features/portfolio/presentation/pages/position_detail_page.dart';
import 'package:arah/features/dca/presentation/bloc/dca_cubit.dart';
import 'package:arah/features/dca/presentation/pages/dca_page.dart';
import 'package:arah/features/dividends/presentation/bloc/dividends_cubit.dart';
import 'package:arah/features/dividends/presentation/pages/dividends_page.dart';
import 'package:arah/features/journal/presentation/bloc/journal_cubit.dart';
import 'package:arah/features/analysis/presentation/bloc/analysis_cubit.dart';
import 'package:arah/features/analysis/presentation/pages/analysis_page.dart';
import 'package:arah/features/analysis/presentation/bloc/technical_rank_cubit.dart';
import 'package:arah/features/analysis/presentation/pages/technical_rank_page.dart';
import 'package:arah/features/calculator/presentation/bloc/insights_cubits.dart';
import 'package:arah/features/calculator/presentation/pages/calculator_page.dart';
import 'package:arah/features/calculator/presentation/pages/calculator_tool_page.dart';
import 'package:arah/features/help/presentation/pages/help_page.dart';
import 'package:arah/features/journal/presentation/pages/journal_page.dart';
import 'package:arah/features/letter/presentation/bloc/letter_cubit.dart';
import 'package:arah/features/letter/presentation/pages/investor_letter_page.dart';
import 'package:arah/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:arah/features/settings/presentation/pages/settings_page.dart';
import 'package:arah/features/watchlist/presentation/bloc/watchlist_cubit.dart';
import 'package:arah/features/watchlist/presentation/pages/watchlist_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Bisa dibuka tanpa login.
const _publicRoutes = {'/login', '/forgot-password'};

Widget _technicalRank() =>
    BlocProvider(create: (_) => sl<TechnicalRankCubit>()..load(), child: const TechnicalRankPage());

GoRouter createRouter(AuthBloc auth) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _StreamListenable(auth.stream),
    redirect: (context, state) {
      final location = state.matchedLocation;
      return switch (auth.state.status) {
        AuthStatus.unknown => location == '/splash' ? null : '/splash',
        // Terkunci: layar masuk menampilkan tombol sidik jari, password tetap bisa dipakai.
        AuthStatus.unauthenticated || AuthStatus.locked => _publicRoutes.contains(location) ? null : '/login',
        AuthStatus.authenticated => _publicRoutes.contains(location) || location == '/splash' ? '/home' : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => BlocProvider(create: (_) => sl<PasswordResetCubit>(), child: const ForgotPasswordPage()),
      ),
      StatefulShellRoute.indexedStack(
        // Bloc fitur hidup selama sesi login: state & filter bertahan saat pindah tab,
        // dan dibuang saat logout agar data akun lama tidak terlihat akun berikutnya.
        builder: (context, state, shell) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<DashboardCubit>()..load()),
            BlocProvider(create: (_) => sl<PortfolioBloc>()..add(const PortfolioRequested())),
            BlocProvider(create: (_) => sl<ChatBloc>()),
            BlocProvider(create: (_) => sl<NetWorthCubit>()..load()),
          ],
          child: AppShell(shell: shell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const HomePage(),
                // Juga di bawah Beranda supaya back dari pintasan kembali ke Beranda, bukan ke Lainnya.
                routes: [GoRoute(path: 'technical-rank', builder: (_, _) => _technicalRank())],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/portfolio',
                builder: (_, state) => PortfolioPage(initialTab: state.uri.queryParameters['tab']),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => PositionDetailPage(positionId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/assistant',
                builder: (_, state) {
                  final q = state.uri.queryParameters;
                  final symbol = q['symbol'];
                  return ChatPage(
                    initialContext: symbol == null
                        ? null
                        : AssetContext(symbol: symbol, exchange: q['exchange'] ?? 'IDX'),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (_, _) => BlocProvider(
                      create: (_) => sl<ConversationHistoryCubit>()..refresh(),
                      child: const ConversationHistoryPage(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/wealth', builder: (_, _) => const NetWorthPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MorePage(),
                routes: [
                  // Rute fitur didahulukan; slug lain jatuh ke :feature (halaman "segera hadir").
                  GoRoute(
                    path: 'watchlist',
                    builder: (_, _) =>
                        BlocProvider(create: (_) => sl<WatchlistCubit>()..load(), child: const WatchlistPage()),
                  ),
                  GoRoute(
                    path: 'dca',
                    builder: (_, _) => BlocProvider(create: (_) => sl<DcaCubit>()..load(), child: const DcaPage()),
                  ),
                  GoRoute(
                    path: 'dividends',
                    builder: (_, _) =>
                        BlocProvider(create: (_) => sl<DividendsCubit>()..load(), child: const DividendsPage()),
                  ),
                  GoRoute(
                    path: 'journal',
                    builder: (_, _) =>
                        BlocProvider(create: (_) => sl<JournalCubit>()..load(), child: const JournalPage()),
                  ),
                  GoRoute(path: 'help', builder: (_, _) => const HelpPage()),
                  GoRoute(
                    path: 'calculator',
                    builder: (_, _) => const CalculatorPage(),
                    routes: [
                      GoRoute(
                        path: ':tool',
                        builder: (_, state) => switch (CalculatorTool.fromSlug(state.pathParameters['tool']!)) {
                          null => const UpcomingFeaturePage(title: 'Kalkulator'),
                          // Cubit data server hanya untuk alat yang memakainya; lazy = tidak memanggil API alat lain.
                          final tool => MultiBlocProvider(
                            providers: [
                              BlocProvider(create: (_) => sl<InvisibleCostCubit>()..load()),
                              BlocProvider(create: (_) => sl<WealthTimelineCubit>()..load()),
                            ],
                            child: CalculatorToolPage(tool: tool),
                          ),
                        },
                      ),
                    ],
                  ),
                  GoRoute(path: 'technical-rank', builder: (_, _) => _technicalRank()),
                  GoRoute(
                    path: 'analysis',
                    builder: (_, _) =>
                        BlocProvider(create: (_) => sl<AnalysisCubit>()..load(), child: const AnalysisPage()),
                  ),
                  GoRoute(
                    path: 'investor-letter',
                    builder: (_, _) =>
                        BlocProvider(create: (_) => sl<LetterCubit>()..load(), child: const InvestorLetterPage()),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) =>
                        BlocProvider(create: (_) => sl<SettingsCubit>()..load(), child: const SettingsPage()),
                  ),
                  GoRoute(
                    path: ':feature',
                    builder: (_, state) =>
                        UpcomingFeaturePage(title: MorePage.titleOf(state.pathParameters['feature']!)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Memicu evaluasi ulang redirect setiap state auth berubah.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
