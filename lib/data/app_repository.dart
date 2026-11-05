import 'package:steady_through/model/app_data.dart';

abstract class AppRepository {
  Future<AppData> load();

  Future<void> save(AppData value);
}
