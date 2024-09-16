import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fire_model/fire_model.dart';
import 'package:fire_model/src/model_list.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

abstract class Repository<T extends Model> extends GetxController {
  /// ## Not for consumer to use directly
  late final FirebaseFirestore db;

  /// ## Not for consumer to use directly
  late final AuthService authService;

  /// This is the table/collection name used
  /// by firestore to save document.
  /// ## Not for consumer to use directly.
  String get collection;

  /// If your document has an user property
  /// Means a document of this collection is
  /// User specific, like a post which must have a user
  /// override and make this true
  /// and must implement the below steps
  /// ### create a field `final String user` in model class
  /// ### Model class constructor `ModelClass({...other fields, this.user = ''})`
  /// ### Repository toFirestore `model.user.isEmpty ? userId : model.user`
  bool get belongsToUser => false;

  /// Limit per page if querying list of documents
  /// Default is 25, override for change.
  /// ## Not for consumer to use directly.
  int get limit => 25;

  @override
  @mustCallSuper
  onInit() {
    super.onInit();
    db = Get.find<FirebaseFirestore>();
    authService = Get.find<AuthService>();
  }

  /// ## Not for consumer to use directly.
  String ensureHasUser() {
    if (authService.user.value == null) {
      throw Exception('User can not be null');
    }
    return authService.user.value!.uid;
  }

  /// Get a specific document by id.
  /// > * _`@param: [id]`_ - document id
  ///
  /// > _`@returns: [T]`_ A model class
  Future<T?> getById(String id) async {
    final response = await collectionReference().doc(id).get();
    return response.data();
  }

  /// Get a list of document.
  /// > * _`@param: [limit]`_ - A limit can be provided, otherwise repo limit will be used
  /// > * _`@param: [lastDoc]`_ - If provided, documents after the lastDoc will be fetched.
  /// > _`@returns: [T]`_ Returns ModelList<T>:
  Future<ModelList<T>> getList({
    int? limit,
    DocumentSnapshot<T>? lastDoc,
  }) async {
    limit ??= this.limit;
    final query = _defaultQuery(limit: limit, lastDoc: lastDoc);

    return getByQuery(query);
  }

  /// ## Not for consumer to use directly.
  /// This is use ful if you have custom query.
  /// Just build the query and call through this method.
  /// For query example see _defaultQuery
  Future<ModelList<T>> getByQuery(Query<T> query) async {
    final response = await query.get();
    final models = responseToList(response);
    DocumentSnapshot<T>? newLastDoc;
    if (models.isNotEmpty && models.length == limit) {
      newLastDoc = response.docs[limit - 1];
    }

    return ModelList(models: models, lastDoc: newLastDoc);
  }

  /// Default query used by getList method
  Query<T> _defaultQuery({
    required int limit,
    DocumentSnapshot<T>? lastDoc,
  }) {
    final ref = collectionReference();

    Query<T>? query;

    if (belongsToUser) {
      final userId = ensureHasUser();
      query = ref.where('user', isEqualTo: userId);
    }

    if (lastDoc != null) {
      if (query != null) {
        query = query.startAfterDocument(lastDoc);
      } else {
        query = ref.startAfterDocument(lastDoc);
      }
    }

    if (query == null) {
      return ref.limit(limit);
    } else {
      return query.limit(limit);
    }
  }

  /// ## Not for consumer to use directly.
  /// Is used to convert a response of firestore
  /// To list of models
  List<T> responseToList(QuerySnapshot<T> response) {
    return response.docs.map((doc) => doc.data()).toList();
  }

  /// Saves a model to database
  Future<void> save(T model) async {
    await collectionReference().doc(model.id).set(model);
  }

  /// Update a already saved model
  Future<void> saveUpdated(T model) async {
    await collectionReference()
        .doc(model.id)
        .set(model, SetOptions(merge: true));
  }

  /// Create a firebase batch.
  /// Don't forget to commit.
  /// > * _`@param: [T]`_ - paramName
  ///
  /// > _`@returns: [T]`_
  WriteBatch batch() => db.batch();

  /// Call when required batch operation
  /// Don't forgot to call commit on batch
  Future<void> batchSave(T model, WriteBatch batch) async {
    final ref = docRef(model);
    batch.set(ref, model);
  }

  /// Call when required batch operation
  /// Don't forgot to call commit on batch
  Future<void> batchUpdate(T model, WriteBatch batch) async {
    final ref = docRef(model);
    batch.set(ref, model, SetOptions(merge: true));
  }

  /// ## Not for consumer to use directly.
  DocumentReference<T> docRef(T model) {
    return collectionReference().doc(model.id);
  }

  /// ## Not for consumer to use directly.
  T fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  );

  /// ## Not for consumer to use directly.
  Map<String, dynamic> toFirestore(T model);

  /// ## Not for consumer to use directly.
  CollectionReference<T> collectionReference() {
    return db.collection(collection).withConverter(
          fromFirestore: fromFirestore,
          toFirestore: (T model, _) => toFirestore(model),
        );
  }
}
