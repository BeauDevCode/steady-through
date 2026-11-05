import 'package:steady_through/model/app_data.dart';

abstract class AppRepository {
  Future<AppData> load();

  Future<void> save(AppData value);
}

/// Optional repository capability used after Delete all. A normal save may
/// leave a stale backup when best-effort cleanup fails; Delete all must report
/// that failure so the app never says personal data was fully removed.
abstract interface class ResidualDataRepository {
  Future<void> purgeResidualData();
}
