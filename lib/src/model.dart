import 'package:uuid/uuid.dart';

/// In your model class constructor
/// Must call super.id
abstract class Model<T> {
  late final String id;

  Model({String? id}) {
    this.id = id ?? const Uuid().v4();
  }

  T copy({Map<String, dynamic>? props});
}
