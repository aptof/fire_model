import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:faker/faker.dart';
import 'package:fire_model/fire_model.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends GetxService with Mock implements AuthService {}

class FakeModel extends Model<FakeModel> {
  final String fake;
  final String user;

  FakeModel({super.id, required this.fake, this.user = ''});

  @override
  FakeModel copy({Map<String, dynamic>? props}) {
    return FakeModel(
      id: props?['id'] ?? id,
      fake: props?['fake'] ?? fake,
      user: props?['user'] ?? user,
    );
  }
}

class RepositoryBelongsToUser extends Repository<FakeModel> {
  @override
  String get collection => 'fakes';

  @override
  int get limit => 3;

  @override
  bool get belongsToUser => true;

  @override
  FakeModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return FakeModel(
      id: snapshot.id,
      fake: data?['fake'] ?? '',
      user: data?['user'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toFirestore(FakeModel model) {
    final userId = ensureHasUser();
    return {
      'fake': model.fake,
      'user': model.user.isEmpty ? userId : model.user,
    };
  }
}

class NoUserFakeModel extends Model<NoUserFakeModel> {
  final String fake;

  NoUserFakeModel({super.id, required this.fake});

  @override
  NoUserFakeModel copy({Map<String, dynamic>? props}) {
    return NoUserFakeModel(
      id: props?['id'] ?? id,
      fake: props?['fake'] ?? fake,
    );
  }
}

class RepoNotBelongsToUser extends Repository<NoUserFakeModel> {
  @override
  String get collection => 'nfakes';

  @override
  int get limit => 3;

  @override
  NoUserFakeModel fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    return NoUserFakeModel(
      id: snapshot.id,
      fake: data?['fake'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toFirestore(NoUserFakeModel model) {
    return {
      'id': model.id,
      'fake': model.fake,
    };
  }
}

void main() {
  final faker = Faker();
  final db = Get.put<FirebaseFirestore>(FakeFirebaseFirestore());
  final auth = Get.put<AuthService>(MockAuthService());
  final mockUser = MockUser();

  group('Belongs to user', () {
    tearDown(() {
      reset(auth);
      db.clearPersistence();
    });

    setUp(() {
      when(() => auth.user).thenReturn(Rxn(mockUser));
    });

    test('save should throw exception if user is null', () async {
      when(() => auth.user).thenReturn(Rxn(null));
      final sut = Get.put(RepositoryBelongsToUser());
      final fakeModel = FakeModel(fake: faker.lorem.word());
      expect(() => sut.save(fakeModel), throwsA(isA<Exception>()));
    });

    test('Save should save with userId', () async {
      final sut = Get.put(RepositoryBelongsToUser());
      final fakeModel = FakeModel(fake: faker.lorem.word(), id: '5');
      await sut.save(fakeModel);

      final res = await db.collection('fakes').doc(fakeModel.id).get();
      final data = res.data();

      expect(data, isNotNull);
      expect(data!['fake'], equals(fakeModel.fake));
      expect(data['user'], equals(mockUser.uid));
    });

    test('Save updated should update the saved data', () async {
      final sut = Get.put(RepositoryBelongsToUser());
      final fakeModel = FakeModel(fake: faker.lorem.word());
      await sut.save(fakeModel);

      final updatedFake = faker.lorem.word();
      final updatedModel = fakeModel.copy(props: {'fake': updatedFake});
      await sut.saveUpdated(updatedModel);

      final res = await db.collection('fakes').doc(fakeModel.id).get();
      final data = res.data();

      expect(data, isNotNull);
      expect(data!['fake'], equals(updatedFake));
      expect(data['user'], equals(mockUser.uid));
    });

    test('GetById -> null when do not exist', () async {
      final differentId = faker.lorem.word();
      final fakeModel = FakeModel(fake: faker.lorem.word());
      final sut = Get.put(RepositoryBelongsToUser());
      await sut.save(fakeModel);

      final actual = await sut.getById(differentId);

      expect(actual, isNull);
    });

    test('GetById -> model when exist', () async {
      final fakeModel = FakeModel(fake: faker.lorem.word(), id: '5');
      final sut = Get.put(RepositoryBelongsToUser());
      await sut.save(fakeModel);

      final actual = await sut.getById(fakeModel.id);

      expect(actual, isNotNull);
      expect(actual!.id, fakeModel.id);
    });

    test('getList -> returns list of model', () async {
      final model1 = FakeModel(fake: faker.lorem.word(), id: '1');
      final model2 = FakeModel(fake: faker.lorem.word(), id: '2');
      final model3 = FakeModel(fake: faker.lorem.word(), id: '3');
      final model4 = FakeModel(fake: faker.lorem.word(), id: '4');
      final model5 = FakeModel(fake: faker.lorem.word(), id: '5');
      final model6 = FakeModel(fake: faker.lorem.word(), id: '6');
      final sut = Get.put(RepositoryBelongsToUser());
      await sut.save(model1);
      await sut.save(model2);
      await sut.save(model3);
      await sut.save(model4);
      await sut.save(model5);

      final differentUser = MockUser();
      // add model6 with different user
      when(() => auth.user).thenReturn(Rxn(differentUser));
      await sut.save(model6);

      // reset user to original one
      when(() => auth.user).thenReturn(Rxn(mockUser));
      final result = await sut.getList();

      expect(result.models.length, 3);
      expect(result.lastDoc, isNotNull);

      final nextResult = await sut.getList(lastDoc: result.lastDoc);

      expect(nextResult.models.length, 2);
      expect(nextResult.lastDoc, isNull);
    });
  });

  group('No user repository', () {
    tearDown(() {
      db.clearPersistence();
    });

    test('save should save data', () async {
      final sut = Get.put(RepoNotBelongsToUser());
      final fakeModel = NoUserFakeModel(fake: faker.lorem.word());
      await sut.save(fakeModel);

      final res = await db.collection('nfakes').doc(fakeModel.id).get();
      final data = res.data();

      expect(data, isNotNull);
      expect(data!['fake'], fakeModel.fake);
    });

    test('getById should get doc by id', () async {
      final sut = Get.put(RepoNotBelongsToUser());
      final fakeModel = NoUserFakeModel(fake: faker.lorem.word());
      await sut.save(fakeModel);
      final actual = await sut.getById(fakeModel.id);

      expect(actual!.id, equals(fakeModel.id));
      expect(actual.fake, equals(fakeModel.fake));
    });

    test('saveUpdated should update data', () async {
      final sut = Get.put(RepoNotBelongsToUser());
      final fakeModel = NoUserFakeModel(fake: faker.lorem.word());
      await sut.save(fakeModel);
      final updatedFake = faker.lorem.word();
      final updatedModel = fakeModel.copy(props: {'fake': updatedFake});

      await sut.saveUpdated(updatedModel);
      final actual = await sut.getById(fakeModel.id);

      expect(actual!.id, equals(fakeModel.id));
      expect(actual.fake, equals(updatedFake));
    });

    test('getList -> returns list of model', () async {
      final model1 = NoUserFakeModel(fake: faker.lorem.word(), id: '1');
      final model2 = NoUserFakeModel(fake: faker.lorem.word(), id: '2');
      final model3 = NoUserFakeModel(fake: faker.lorem.word(), id: '3');
      final model4 = NoUserFakeModel(fake: faker.lorem.word(), id: '4');
      final model5 = NoUserFakeModel(fake: faker.lorem.word(), id: '5');

      final sut = Get.put(RepoNotBelongsToUser());
      await sut.save(model1);
      await sut.save(model2);
      await sut.save(model3);
      await sut.save(model4);
      await sut.save(model5);

      final result = await sut.getList();

      expect(result.models.length, 3);
      expect(result.lastDoc, isNotNull);

      final nextResult = await sut.getList(lastDoc: result.lastDoc);

      expect(nextResult.models.length, 2);
      expect(nextResult.lastDoc, isNull);
    });
  });
}
