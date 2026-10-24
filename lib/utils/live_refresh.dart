import 'package:flutter/foundation.dart';

/// Sinyal ringan supaya daftar jurnal dan izin ikut berubah
/// begitu data baru tersimpan, tanpa menunggu tarik-untuk-refresh.
class LiveRefresh {
  static final journals = ValueNotifier<int>(0);
  static final leaves = ValueNotifier<int>(0);

  static void pingJournals() => journals.value++;
  static void pingLeaves() => leaves.value++;
}
