import 'package:cloud_firestore/cloud_firestore.dart';

class ModelList<T> {
  final List<T> models;

  /// Use this to get next batch of documents
  /// required by the getList method of repository
  /// If its value is null, no more documents are available
  /// in database after this.
  final DocumentSnapshot<T>? lastDoc;

  ModelList({required this.models, required this.lastDoc});
}
