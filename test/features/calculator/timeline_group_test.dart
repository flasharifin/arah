import 'package:arah/core/domain/money.dart';
import 'package:arah/features/calculator/domain/entities/insights.dart';
import 'package:flutter_test/flutter_test.dart';

TimelineEvent _e(int month, int day, String label) =>
    TimelineEvent(date: DateTime(2026, month, day), kind: TimelineKind.buy, label: label, amount: const Money.idr(1));

void main() {
  test('dikelompokkan per bulan, urutan dari server dipertahankan, bulan sama tidak terpecah', () {
    final groups = groupTimelineByMonth([_e(11, 20, 'a'), _e(11, 2, 'b'), _e(9, 30, 'c'), _e(11, 1, 'd')]);
    expect(groups.map((g) => g.month), [DateTime(2026, 11), DateTime(2026, 9)]);
    expect(groups.first.events.map((e) => e.label), ['a', 'b', 'd']);
    expect(groups.last.events.map((e) => e.label), ['c']);
    expect(groupTimelineByMonth(const []), isEmpty);
  });
}
