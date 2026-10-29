import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/domain/usecases/conversation_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Riwayat percakapan AI. Aksi ubah nama & hapus mengembalikan [Result] supaya halaman bisa
/// menampilkan gagal tanpa membuang daftar yang sudah tampil.
class ConversationHistoryCubit extends Cubit<ViewState<List<ConversationSummary>>> {
  ConversationHistoryCubit({
    required ListConversations list,
    required LoadConversation load,
    required RenameConversation rename,
    required DeleteConversation delete,
  }) : _list = list,
       _load = load,
       _rename = rename,
       _delete = delete,
       super(const ViewState());

  final ListConversations _list;
  final LoadConversation _load;
  final RenameConversation _rename;
  final DeleteConversation _delete;

  Future<void> refresh() async {
    emit(state.loading());
    emit(state.fromResult(await _list(const NoParams())));
  }

  Future<Result<List<ChatMessage>>> open(String id) => _load(id);

  Future<Result<void>> rename(String id, String title) async {
    final result = await _rename((id: id, title: title));
    if (result is Success<void>) {
      emit(
        ViewState(
          status: state.status,
          data: [
            for (final c in state.data ?? <ConversationSummary>[])
              c.id == id ? ConversationSummary(id: c.id, title: title.trim(), updatedAt: c.updatedAt) : c,
          ],
        ),
      );
    }
    return result;
  }

  Future<Result<void>> delete(String id) async {
    final result = await _delete(id);
    if (result is Success<void>) {
      emit(ViewState(status: state.status, data: [...?state.data?.where((c) => c.id != id)]));
    }
    return result;
  }
}
