import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/fan_works/repositories/shared_preferences_fan_work_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fan work drafts persist across app restarts (file-backed)', () async {
    final first = SharedPreferencesFanWorkDraftStore();
    await first.write('new', <String, dynamic>{
      'type': 'manga',
      'title': 'Sunny Page',
      'pageIds': <String>['img-1'],
      'pageCaptions': <String, String>{'img-1': 'First panel'},
    });
    await first.write('work-9', <String, dynamic>{
      'type': 'story',
      'title': 'Tale',
    });

    final second = SharedPreferencesFanWorkDraftStore();
    final restored = await second.read('new');
    expect(restored, isNotNull);
    expect(restored!['type'], 'manga');
    expect(restored['title'], 'Sunny Page');
    expect((restored['pageIds'] as List).single, 'img-1');
    expect((restored['pageCaptions'] as Map)['img-1'], 'First panel');
    expect((await second.read('work-9'))?['title'], 'Tale');

    await second.delete('new');
    expect(await second.read('new'), isNull);
    expect((await second.read('work-9'))?['title'], 'Tale');
  });

  test('fan work draft store tolerates corrupt storage', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fan_work_drafts_v1', 'not-json{{');
    final store = SharedPreferencesFanWorkDraftStore(preferences: prefs);
    expect(await store.read('anything'), isNull);
    await store.write('anything', <String, dynamic>{'type': 'drawing'});
    expect((await store.read('anything'))?['type'], 'drawing');
  });
}
