import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:love_space/data/repositories/racing_score_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('missing score returns zero', () async {
    const repository = RacingScoreRepository();

    expect(await repository.getBestDistance(), 0);
  });

  test('higher score persists across repository instances', () async {
    const first = RacingScoreRepository();
    expect(await first.saveIfHigher(860), isTrue);

    const second = RacingScoreRepository();
    expect(await second.getBestDistance(), 860);
  });

  test('lower or equal score never replaces the record', () async {
    SharedPreferences.setMockInitialValues({
      RacingScoreRepository.storageKey: 1200,
    });
    const repository = RacingScoreRepository();

    expect(await repository.saveIfHigher(900), isFalse);
    expect(await repository.saveIfHigher(1200), isFalse);
    expect(await repository.getBestDistance(), 1200);
  });
}
