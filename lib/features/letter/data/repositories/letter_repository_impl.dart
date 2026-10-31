import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/letter/data/datasources/letter_remote_data_source.dart';
import 'package:arah/features/letter/domain/entities/investor_letter.dart';
import 'package:arah/features/letter/domain/repositories/letter_repository.dart';

class LetterRepositoryImpl implements LetterRepository {
  const LetterRepositoryImpl(this._remote);
  final LetterRemoteDataSource _remote;

  @override
  Future<Result<InvestorLetter>> get() => guard(_remote.fetch);
}
