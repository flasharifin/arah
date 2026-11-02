import 'dart:async';

import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';
import 'package:arah/features/notifications/domain/usecases/notification_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationsCubit extends Cubit<ViewState<List<AppNotification>>> {
  NotificationsCubit({required GetNotifications get, required MarkNotificationRead mark})
    : _get = get,
      _mark = mark,
      super(const ViewState());

  final GetNotifications _get;
  final MarkNotificationRead _mark;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }

  /// [id] null = semua. Tampilan langsung berubah; kalau server gagal, muat ulang supaya tetap jujur.
  Future<void> markRead(String? id) async {
    final items = state.data;
    if (items == null) return;
    emit(ViewState(status: ViewStatus.success, data: [for (final n in items) id == null || n.id == id ? n.read() : n]));
    if (await _mark(id) is! Success<void>) await load();
  }
}

/// Angka di lonceng Beranda. Gagal memuat tidak ditampilkan: lencana bukan alasan untuk mengganggu Beranda.
class UnreadNotificationsCubit extends Cubit<int> {
  UnreadNotificationsCubit({required GetUnreadNotificationCount get, required Stream<void> pushes})
    : _get = get,
      super(0) {
    _pushes = pushes.listen((_) => load());
  }

  final GetUnreadNotificationCount _get;
  late final StreamSubscription<void> _pushes;

  Future<void> load() async {
    final result = await _get(const NoParams());
    if (!isClosed && result is Success<int>) emit(result.data);
  }

  @override
  Future<void> close() {
    _pushes.cancel();
    return super.close();
  }
}

class NotificationPrefsCubit extends Cubit<ViewState<NotificationPrefs>> {
  NotificationPrefsCubit({required GetNotificationPrefs get, required SaveNotificationPrefs save})
    : _get = get,
      _save = save,
      super(const ViewState());

  final GetNotificationPrefs _get;
  final SaveNotificationPrefs _save;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }

  /// Tombol langsung berubah; kalau gagal, kembali ke nilai lama dan pemanggil menampilkan pesannya.
  Future<Result<void>> save(NotificationPrefs prefs) async {
    final previous = state.data;
    emit(ViewState(status: ViewStatus.success, data: prefs));
    final result = await _save(prefs);
    if (result is! Success<void> && !isClosed) emit(ViewState(status: ViewStatus.success, data: previous));
    return result;
  }
}
