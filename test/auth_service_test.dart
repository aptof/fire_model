import 'package:faker/faker.dart';
import 'package:fire_model/fire_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:get/get.dart';

void main() {
  final faker = Faker();
  final user = MockUser(
      isAnonymous: false,
      uid: faker.lorem.word(),
      email: faker.internet.email(),
      displayName: faker.person.name());
  final auth = MockFirebaseAuth(mockUser: user);
  Get.put<FirebaseAuth>(auth);

  test('At initial -> user is null', () {
    final service = Get.put(AuthService());
    expect(service.user.value, isNull);
  });

  test('On login -> user should set', () async {
    final service = Get.put(AuthService());
    await service.login(
      email: faker.internet.email(),
      password: faker.lorem.word(),
    );

    expect(service.user.value, user);
  });

  test('On logout -> user should be null', () async {
    final service = Get.put(AuthService());
    await service.login(
      email: faker.internet.email(),
      password: faker.lorem.word(),
    );
    await service.logOut();

    expect(service.user.value, isNull);
  });
}
