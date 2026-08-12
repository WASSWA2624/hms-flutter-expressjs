import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/shared/data/data.dart';

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

  group('loadMatchingAppPageItems', () {
    test('walks pages until hasNextPage is false', () async {
      final Result<List<int>> result = await loadMatchingAppPageItems<int>(
        pageSize: 2,
        loadPage: (AppPageRequest request) async {
          final List<int> all = <int>[1, 2, 3, 4, 5];
          final int start = request.offset;
          final int end = (start + request.pageSize).clamp(0, all.length);
          return Result<AppPage<int>>.success(
            AppPage<int>(
              items: all.sublist(start, end),
              request: request,
              totalItemCount: all.length,
            ),
          );
        },
      );

      expect(
        result.when(
          success: (List<int> items) => items,
          failure: (_) => <int>[],
        ),
        <int>[1, 2, 3, 4, 5],
      );
    });

    test('clamps page size to AppPageRequest.maxPageSize', () async {
      AppPageRequest? seen;
      await loadMatchingAppPageItems<int>(
        pageSize: AppPageRequest.maxPageSize + 50,
        loadPage: (AppPageRequest request) async {
          seen = request;
          return Result<AppPage<int>>.success(
            AppPage<int>(
              items: const <int>[1],
              request: request,
              totalItemCount: 1,
            ),
          );
        },
      );
      expect(seen?.pageSize, AppPageRequest.maxPageSize);
    });
  });
}
