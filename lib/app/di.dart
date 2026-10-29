import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/assistant/data/datasources/assistant_remote_data_source.dart';
import 'package:arah/features/assistant/data/repositories/assistant_repository_impl.dart';
import 'package:arah/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:arah/features/assistant/domain/usecases/send_chat_message.dart';
import 'package:arah/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:arah/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:arah/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:arah/features/auth/domain/repositories/auth_repository.dart';
import 'package:arah/features/auth/domain/usecases/auth_usecases.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arah/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:arah/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:arah/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:arah/features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:arah/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:arah/features/networth/data/datasources/net_worth_remote_data_source.dart';
import 'package:arah/features/networth/data/repositories/net_worth_repository_impl.dart';
import 'package:arah/features/networth/domain/repositories/net_worth_repository.dart';
import 'package:arah/features/networth/domain/usecases/get_net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/portfolio/data/datasources/portfolio_remote_data_source.dart';
import 'package:arah/features/portfolio/data/repositories/portfolio_repository_impl.dart';
import 'package:arah/features/portfolio/domain/repositories/portfolio_repository.dart';
import 'package:arah/features/portfolio/domain/usecases/get_portfolio.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

/// `--dart-define=USE_FIXTURES=false` memakai backend (default URL produksi).
/// Backend lain: `--dart-define=API_BASE_URL=https://...` — `localhost` di HP/emulator menunjuk ke
/// perangkat itu sendiri, dan `http://` diblokir Android/iOS; pakai URL https (mis. tunnel ke dev server).
const _useFixtures = bool.fromEnvironment('USE_FIXTURES', defaultValue: true);
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dashboard-finance-tracker.vercel.app',
);

/// Komposisi dependensi. Bloc didaftarkan sebagai factory: dibuat baru setiap login.
/// [useFixtures] bisa dipaksa di tes supaya tidak bergantung pada `--dart-define`.
void configureDependencies({bool useFixtures = _useFixtures}) {
  sl
    // Core
    ..registerLazySingleton(() => const TokenStorage(FlutterSecureStorage()))
    ..registerLazySingleton(() => ApiClient(baseUrl: _baseUrl, tokenStorage: sl()))
    ..registerLazySingleton(() => PushNotificationService(api: useFixtures ? null : sl()))
    // Auth
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => useFixtures ? AuthFixtureDataSource() : AuthApiDataSource(sl(), sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        sl(),
        sl(),
        beforeSignOut: () => sl<PushNotificationService>().unregisterDevice(),
      ),
    )
    ..registerFactory(
      () => AuthBloc(getCurrentUser: GetCurrentUser(sl()), signIn: SignIn(sl()), signOut: SignOut(sl())),
    )
    // Dashboard
    ..registerLazySingleton<DashboardRemoteDataSource>(
      () => useFixtures ? DashboardFixtureDataSource() : DashboardApiDataSource(sl()),
    )
    ..registerLazySingleton<DashboardRepository>(() => DashboardRepositoryImpl(sl()))
    ..registerFactory(() => DashboardCubit(GetDashboardSummary(sl())))
    // Portfolio
    ..registerLazySingleton<PortfolioRemoteDataSource>(
      () => useFixtures ? PortfolioFixtureDataSource() : PortfolioApiDataSource(sl()),
    )
    ..registerLazySingleton<PortfolioRepository>(() => PortfolioRepositoryImpl(sl()))
    ..registerFactory(() => PortfolioBloc(GetPortfolio(sl())))
    // Assistant
    ..registerLazySingleton<AssistantRemoteDataSource>(AssistantFixtureDataSource.new)
    ..registerLazySingleton<AssistantRepository>(() => AssistantRepositoryImpl(sl()))
    ..registerFactory(() => ChatBloc(sendMessage: SendChatMessage(sl())))
    // Net worth
    ..registerLazySingleton<NetWorthRemoteDataSource>(
      () => useFixtures ? NetWorthFixtureDataSource() : NetWorthApiDataSource(sl()),
    )
    ..registerLazySingleton<NetWorthRepository>(() => NetWorthRepositoryImpl(sl()))
    ..registerFactory(() => NetWorthCubit(GetNetWorth(sl())));
}
