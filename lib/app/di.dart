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

/// `flutter run --dart-define=USE_FIXTURES=false --dart-define=API_BASE_URL=https://...`
const _useFixtures = bool.fromEnvironment('USE_FIXTURES', defaultValue: true);
const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');

/// Komposisi dependensi. Bloc didaftarkan sebagai factory: dibuat baru setiap login.
void configureDependencies() {
  sl
    // Core
    ..registerLazySingleton(() => const TokenStorage(FlutterSecureStorage()))
    ..registerLazySingleton(() => ApiClient(baseUrl: _baseUrl, tokenStorage: sl()))
    ..registerLazySingleton(PushNotificationService.new)
    // Auth
    ..registerLazySingleton<AuthRemoteDataSource>(AuthFixtureDataSource.new)
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl()))
    ..registerFactory(
      () => AuthBloc(getCurrentUser: GetCurrentUser(sl()), signIn: SignIn(sl()), signOut: SignOut(sl())),
    )
    // Dashboard
    ..registerLazySingleton<DashboardRemoteDataSource>(DashboardFixtureDataSource.new)
    ..registerLazySingleton<DashboardRepository>(() => DashboardRepositoryImpl(sl()))
    ..registerFactory(() => DashboardCubit(GetDashboardSummary(sl())))
    // Portfolio
    ..registerLazySingleton<PortfolioRemoteDataSource>(
      () => _useFixtures ? PortfolioFixtureDataSource() : PortfolioApiDataSource(sl()),
    )
    ..registerLazySingleton<PortfolioRepository>(() => PortfolioRepositoryImpl(sl()))
    ..registerFactory(() => PortfolioBloc(GetPortfolio(sl())))
    // Assistant
    ..registerLazySingleton<AssistantRemoteDataSource>(AssistantFixtureDataSource.new)
    ..registerLazySingleton<AssistantRepository>(() => AssistantRepositoryImpl(sl()))
    ..registerFactory(() => ChatBloc(sendMessage: SendChatMessage(sl())))
    // Net worth
    ..registerLazySingleton<NetWorthRemoteDataSource>(NetWorthFixtureDataSource.new)
    ..registerLazySingleton<NetWorthRepository>(() => NetWorthRepositoryImpl(sl()))
    ..registerFactory(() => NetWorthCubit(GetNetWorth(sl())));
}
