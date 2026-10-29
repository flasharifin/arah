import 'package:arah/core/error/failure.dart';
import 'package:arah/core/error/result.dart';
import 'package:equatable/equatable.dart';

enum ViewStatus { initial, loading, success, failure }

/// State baca-data generik untuk semua fitur.
/// Data lama dipertahankan saat refresh dan saat gagal, sesuai aturan
/// "Refresh: pertahankan data lama" di doc/designapp/02-navigasi-dan-alur.md.
class ViewState<T> extends Equatable {
  const ViewState({this.status = ViewStatus.initial, this.data, this.failure});

  final ViewStatus status;
  final T? data;
  final Failure? failure;

  bool get isLoading => status == ViewStatus.loading;
  bool get isRefreshing => isLoading && data != null;

  ViewState<T> loading() => ViewState(status: ViewStatus.loading, data: data);

  ViewState<T> fromResult(Result<T> result) => result.fold(
    (failure) => ViewState(status: ViewStatus.failure, data: data, failure: failure),
    (data) => ViewState(status: ViewStatus.success, data: data),
  );

  @override
  List<Object?> get props => [status, data, failure];
}
