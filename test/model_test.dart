import 'package:faker/faker.dart';
import 'package:fire_model/fire_model.dart';
import 'package:flutter_test/flutter_test.dart';

class DemoModel extends Model<DemoModel> {
  final String demoField;

  DemoModel({super.id, required this.demoField});

  @override
  DemoModel copy({Map<String, dynamic>? props}) {
    return DemoModel(
      id: props?['id'] ?? id,
      demoField: props?['demoField'] ?? demoField,
    );
  }
}

void main() {
  final faker = Faker();

  test('Model should have an id', () {
    final model = DemoModel(demoField: faker.lorem.word());
    expect(model.id, isNotEmpty);
  });
}
