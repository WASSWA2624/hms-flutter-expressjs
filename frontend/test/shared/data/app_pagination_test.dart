import 'package:flutter_template/shared/data/data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPageRequest', () {
    test('exposes offset and limit for repository queries', () {
      const request = AppPageRequest(pageIndex: 2, pageSize: 25);

      expect(request.offset, 50);
      expect(request.limit, 25);
    });

    test('does not move before the first page', () {
      const request = AppPageRequest();

      expect(request.previous(), request);
    });
  });

  group('AppPage', () {
    test('uses total count when deciding if another page exists', () {
      const request = AppPageRequest(pageIndex: 1, pageSize: 10);
      const page = AppPage<int>(
        items: <int>[10, 11, 12],
        request: request,
        totalItemCount: 13,
      );

      expect(page.firstItemNumber, 11);
      expect(page.lastItemNumber, 13);
      expect(page.hasPreviousPage, isTrue);
      expect(page.hasNextPage, isFalse);
    });

    test(
      'treats a full page without total count as potentially continuing',
      () {
        const request = AppPageRequest(pageSize: 2);
        const page = AppPage<int>(items: <int>[1, 2], request: request);

        expect(page.hasNextPage, isTrue);
      },
    );
  });
}
