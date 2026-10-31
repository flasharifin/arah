import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/security/biometric_lock.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/assistant/data/datasources/assistant_remote_data_source.dart';
import 'package:arah/features/assistant/data/repositories/assistant_repository_impl.dart';
import 'package:arah/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:arah/features/assistant/domain/usecases/send_chat_message.dart';
import 'package:arah/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:arah/features/assistant/domain/usecases/conversation_usecases.dart';
import 'package:arah/features/assistant/presentation/bloc/conversation_history_cubit.dart';
import 'package:arah/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:arah/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:arah/features/auth/domain/repositories/auth_repository.dart';
import 'package:arah/features/auth/domain/usecases/auth_usecases.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arah/features/auth/presentation/bloc/password_reset_cubit.dart';
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
import 'package:arah/features/portfolio/data/datasources/performance_remote_data_source.dart';
import 'package:arah/features/portfolio/data/datasources/portfolio_remote_data_source.dart';
import 'package:arah/features/portfolio/data/repositories/performance_repository_impl.dart';
import 'package:arah/features/portfolio/data/repositories/portfolio_repository_impl.dart';
import 'package:arah/features/portfolio/domain/repositories/performance_repository.dart';
import 'package:arah/features/portfolio/domain/repositories/portfolio_repository.dart';
import 'package:arah/features/portfolio/domain/usecases/performance_usecases.dart';
import 'package:arah/features/portfolio/domain/usecases/get_portfolio.dart';
import 'package:arah/features/portfolio/domain/usecases/record_purchase.dart';
import 'package:arah/features/portfolio/presentation/bloc/performance_cubit.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/dca/data/datasources/dca_remote_data_source.dart';
import 'package:arah/features/dca/data/repositories/dca_repository_impl.dart';
import 'package:arah/features/dca/domain/repositories/dca_repository.dart';
import 'package:arah/features/dca/domain/usecases/dca_usecases.dart';
import 'package:arah/features/dca/presentation/bloc/dca_cubit.dart';
import 'package:arah/features/dividends/data/datasources/dividend_remote_data_source.dart';
import 'package:arah/features/dividends/data/repositories/dividend_repository_impl.dart';
import 'package:arah/features/dividends/domain/repositories/dividend_repository.dart';
import 'package:arah/features/dividends/domain/usecases/get_dividends.dart';
import 'package:arah/features/dividends/presentation/bloc/dividends_cubit.dart';
import 'package:arah/features/journal/data/datasources/journal_remote_data_source.dart';
import 'package:arah/features/journal/data/repositories/journal_repository_impl.dart';
import 'package:arah/features/journal/domain/repositories/journal_repository.dart';
import 'package:arah/features/journal/domain/usecases/journal_usecases.dart';
import 'package:arah/features/journal/presentation/bloc/journal_cubit.dart';
import 'package:arah/features/watchlist/data/datasources/watchlist_remote_data_source.dart';
import 'package:arah/features/watchlist/data/repositories/watchlist_repository_impl.dart';
import 'package:arah/features/watchlist/domain/repositories/watchlist_repository.dart';
import 'package:arah/features/watchlist/domain/usecases/watchlist_usecases.dart';
import 'package:arah/features/watchlist/presentation/bloc/watchlist_cubit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

/// `--dart-define=USE_FIXTURES=false` memakai backend (default URL produksi).
/// Backend lain: `--dart-define=API_BASE_URL=https://...` — `localhost` di HP/emulator menunjuk ke
/// perangkat itu sendiri, dan `http://` diblokir Android/iOS; pakai URL https (mis. tunnel ke dev server).
const _useFixtures = bool.fromEnvironment('USE_FIXTURES', defaultValue: true);
const _baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://dashboard-finance-tracker.vercel.app');

/// Komposisi dependensi. Bloc didaftarkan sebagai factory: dibuat baru setiap login.
/// [useFixtures] bisa dipaksa di tes supaya tidak bergantung pada `--dart-define`.
void configureDependencies({bool useFixtures = _useFixtures}) {
  sl
    // Core
    ..registerLazySingleton(() => const TokenStorage(FlutterSecureStorage()))
    ..registerLazySingleton(() => ApiClient(baseUrl: _baseUrl, tokenStorage: sl()))
    ..registerLazySingleton(() => PushNotificationService(api: useFixtures ? null : sl()))
    ..registerLazySingleton(() => BiometricLock(const FlutterSecureStorage()))
    // Auth
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => useFixtures ? AuthFixtureDataSource() : AuthApiDataSource(sl(), sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(sl(), sl(), beforeSignOut: () => sl<PushNotificationService>().unregisterDevice()),
    )
    ..registerFactory(
      () => AuthBloc(
        getCurrentUser: GetCurrentUser(sl()),
        signIn: SignIn(sl()),
        signOut: SignOut(sl()),
        deleteAccount: DeleteAccount(sl()),
        biometricLock: sl(),
      ),
    )
    ..registerFactory(
      () => PasswordResetCubit(requestReset: RequestPasswordReset(sl()), resetPassword: ResetPassword(sl())),
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
    ..registerLazySingleton<PerformanceRemoteDataSource>(
      () => useFixtures ? PerformanceFixtureDataSource() : PerformanceApiDataSource(sl()),
    )
    ..registerLazySingleton<PerformanceRepository>(() => PerformanceRepositoryImpl(sl()))
    ..registerFactory(() => PerformanceCubit(GetDailyPerformance(sl())))
    ..registerFactory(() => SalesCubit(GetSales(sl())))
    ..registerFactory(() => RecordPurchase(sl()))
    // Assistant
    ..registerLazySingleton<AssistantRemoteDataSource>(
      () => useFixtures ? AssistantFixtureDataSource() : AssistantApiDataSource(sl()),
    )
    ..registerLazySingleton<AssistantRepository>(() => AssistantRepositoryImpl(sl()))
    ..registerFactory(() => ChatBloc(sendMessage: SendChatMessage(sl())))
    ..registerFactory(
      () => ConversationHistoryCubit(
        list: ListConversations(sl()),
        load: LoadConversation(sl()),
        rename: RenameConversation(sl()),
        delete: DeleteConversation(sl()),
      ),
    )
    // Net worth
    ..registerLazySingleton<NetWorthRemoteDataSource>(
      () => useFixtures ? NetWorthFixtureDataSource() : NetWorthApiDataSource(sl()),
    )
    ..registerLazySingleton<NetWorthRepository>(() => NetWorthRepositoryImpl(sl()))
    ..registerFactory(
      () => NetWorthCubit(
        get: GetNetWorth(sl()),
        save: SaveWealthEntry(sl()),
        remove: RemoveWealthEntry(sl()),
        snapshot: CreateNetWorthSnapshot(sl()),
        removeSnapshot: RemoveNetWorthSnapshot(sl()),
      ),
    )
    // Watchlist
    ..registerLazySingleton<WatchlistRemoteDataSource>(
      () => useFixtures ? WatchlistFixtureDataSource() : WatchlistApiDataSource(sl()),
    )
    ..registerLazySingleton<WatchlistRepository>(() => WatchlistRepositoryImpl(sl()))
    ..registerFactory(
      () => WatchlistCubit(get: GetWatchlist(sl()), save: SaveWatchItem(sl()), remove: RemoveWatchItem(sl())),
    )
    // DCA
    ..registerLazySingleton<DcaRemoteDataSource>(() => useFixtures ? DcaFixtureDataSource() : DcaApiDataSource(sl()))
    ..registerLazySingleton<DcaRepository>(() => DcaRepositoryImpl(sl()))
    ..registerFactory(
      () => DcaCubit(
        get: GetDcaOverview(sl()),
        record: RecordDcaExecution(sl()),
        savePlan: SaveDcaPlan(sl()),
        deletePlan: DeleteDcaPlan(sl()),
        getPortfolio: GetPortfolio(sl()),
      ),
    )
    // Dividen
    ..registerLazySingleton<DividendRemoteDataSource>(
      () => useFixtures ? DividendFixtureDataSource() : DividendApiDataSource(sl()),
    )
    ..registerLazySingleton<DividendRepository>(() => DividendRepositoryImpl(sl()))
    ..registerFactory(
      () => DividendsCubit(
        get: GetDividends(sl()),
        save: SaveDividend(sl()),
        remove: RemoveDividend(sl()),
        getPortfolio: GetPortfolio(sl()),
      ),
    )
    // Jurnal
    ..registerLazySingleton<JournalRemoteDataSource>(
      () => useFixtures ? JournalFixtureDataSource() : JournalApiDataSource(sl()),
    )
    ..registerLazySingleton<JournalRepository>(() => JournalRepositoryImpl(sl()))
    ..registerFactory(() => JournalCubit(get: GetJournal(sl()), save: SaveJournalNote(sl())));
}
