import 'dart:async';

import 'package:arah/app/app_shell.dart';
import 'package:arah/app/di.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:arah/features/assistant/presentation/pages/chat_page.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

GoRouter createRouter(AuthBloc auth) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _StreamListenable(auth.stream),
    redirect: (context, state) {
      final location = state.matchedLocation;
      return switch (auth.state.status) {
        AuthStatus.unknown => location == '/splash' ? null : '/splash',
        AuthStatus.unauthenticated => location == '/login' ? null : '/login',
        AuthStatus.authenticated => location == '/login' || location == '/splash' ? '/home' : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
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
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/portfolio',
                builder: (_, _) => const PortfolioPage(),
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
