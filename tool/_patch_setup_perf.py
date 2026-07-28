from pathlib import Path
import re

path = Path(
    r"D:\coding\apps\flutter\hms\frontend\lib\features\tenant_facility\presentation\pages\tenant_facility_setup_page.dart"
)
text = path.read_text(encoding="utf-8")

old_list = """  static const AppPageRequest _listRequest = AppPageRequest(
    pageSize: AppPageRequest.maxPageSize,
  );"""

new_list = """  static const AppPageRequest _lookupOptionsRequest = AppPageRequest(
    pageSize: PlatformAdminListConfig.pageSize,
  );

  AppPageRequest _pageRequest = PlatformAdminListConfig.initialPageRequest;
  int _totalItemCount = 0;
  String _searchQuery = '';
  String? _statusFilter;
  Timer? _searchDebounce;"""

# Only replace in the five structure sections (departments..beds). Those are the
# first five occurrences of this exact block in the file today.
parts = text.split(old_list)
print("listRequest parts:", len(parts) - 1)
if len(parts) - 1 < 5:
    raise SystemExit("expected at least 5 _listRequest blocks")

text = old_list.join(parts[:6])  # first 5 replacements done via join trick
# Actually split/join: parts[0] + new + parts[1] + new + ... + parts[5] + old + rest
rebuilt = parts[0]
for i, part in enumerate(parts[1:], start=1):
    rebuilt += (new_list if i <= 5 else old_list) + part
text = rebuilt

# Similarity lookup requests: shrink maxPageSize peer loads used by forms.
# Replace "Always load the full..." blocks to single bounded peer fetch.
text2 = text
text2 = text2.replace(
    """    // Always load the full facility peer set first. Search-only loading misses
    // near-matches that do not contain the typed query as a literal substring
    // (for example "Emergancy" vs "Emergency").
    await appendMatches(null);
""",
    """    // Bounded peer set only — backend confirm_similar remains authoritative.
    await appendMatches(null);
""",
)
text2 = text2.replace(
    """    // Always load the full facility peer set first for cross-department
""",
    """    // Bounded peer set only — backend confirm_similar remains authoritative.
""",
)
text2 = text2.replace(
    """    // Always load the full facility peer set first.
    await appendMatches(null);
""",
    """    // Bounded peer set only — backend confirm_similar remains authoritative.
    await appendMatches(null);
""",
)

# Shrink form lookup page sizes from 100 to PlatformAdminListConfig.pageSize
old_lookup = """  static const AppPageRequest _lookupRequest = AppPageRequest(
    pageSize: 100,
  );"""
new_lookup = """  static const AppPageRequest _lookupRequest = AppPageRequest(
    pageSize: PlatformAdminListConfig.pageSize,
  );"""
print("_lookupRequest 100 count:", text2.count(old_lookup))
text2 = text2.replace(old_lookup, new_lookup)

# Also replace pageSize: AppPageRequest.maxPageSize in _lookupRequest if present
old_lookup2 = """  static const AppPageRequest _lookupRequest = AppPageRequest(
    pageSize: AppPageRequest.maxPageSize,
  );"""
print("_lookupRequest max count:", text2.count(old_lookup2))
text2 = text2.replace(old_lookup2, new_lookup)

path.write_text(text2, encoding="utf-8")
print("patched ok")
