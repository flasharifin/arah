import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/journal/domain/entities/journal.dart';
import 'package:arah/features/journal/domain/repositories/journal_repository.dart';

class GetJournal implements UseCase<JournalData, NoParams> {
  const GetJournal(this._repository);
  final JournalRepository _repository;

  @override
  Future<Result<JournalData>> call(NoParams params) => _repository.load();
}

class SaveJournalNote implements UseCase<void, ({String day, String note})> {
  const SaveJournalNote(this._repository);
  final JournalRepository _repository;

  @override
  Future<Result<void>> call(({String day, String note}) params) => _repository.saveNote(params.day, params.note);
}
