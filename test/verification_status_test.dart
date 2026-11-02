import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/verification_repository.dart';
import 'package:auto_podbor_mobile/state/verification_status.dart';

class _Repo implements VerificationRepository {
  Completer<VerificationSummary> next = Completer();
  int calls = 0;

  @override
  Future<VerificationSummary> fetchSummary() {
    calls++;
    return next.future;
  }
}

const _summary = VerificationSummary(passed: 4, total: 4, complete: true);

void main() {
  test('одновременные refresh() — один запрос', () async {
    final repo = _Repo();
    final status = VerificationStatus(repo);
    final a = status.refresh();
    final b = status.refresh();
    expect(status.loading, isTrue);
    repo.next.complete(_summary);
    await Future.wait([a, b]);
    expect(repo.calls, 1);
    expect(status.summary, same(_summary));
    expect(status.loading, isFalse);
  });

  test('сбой после удачи оставляет прежний статус', () async {
    final repo = _Repo()..next.complete(_summary);
    final status = VerificationStatus(repo);
    await status.refresh();

    repo.next = Completer();
    final failing = status.refresh();
    repo.next.completeError(ApiException(500, '{"message":"Сбой"}'));
    await failing;

    expect(status.summary, same(_summary));
    expect(status.error, isNotNull);
  });

  test('ensureLoaded() при готовом статусе в сеть не ходит', () async {
    final repo = _Repo()..next.complete(_summary);
    final status = VerificationStatus(repo);
    await status.ensureLoaded();
    await status.ensureLoaded();
    expect(repo.calls, 1);
  });

  test('clear() обнуляет, и ответ до выхода уже не применяется', () async {
    final repo = _Repo();
    final status = VerificationStatus(repo);
    final pending = status.refresh();
    await Future<void>.delayed(Duration.zero);
    status.clear();
    repo.next.complete(_summary);
    await pending;

    expect(status.summary, isNull);
    expect(status.error, isNull);
    expect(status.loading, isFalse);
  });
}
