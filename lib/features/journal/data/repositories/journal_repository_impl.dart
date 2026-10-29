import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/journal/data/datasources/journal_remote_data_source.dart';
import 'package:arah/features/journal/domain/entities/journal.dart';
import 'package:arah/features/journal/domain/repositories/journal_repository.dart';

class JournalRepositoryImpl implements JournalRepository {
  const JournalRepositoryImpl(this._remote);
  final JournalRemoteDataSource _remote;

  @override
  Future<Result<JournalData>> load() => guard(_remote.load);

  @override
  Future<Result<void>> saveNote(String day, String note) => guard(() => _remote.saveNote(day, note.trim()));
}
