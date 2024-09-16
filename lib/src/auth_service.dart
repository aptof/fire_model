import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends GetxService {
  final user = Rxn<User>(null);
  final _auth = Get.find<FirebaseAuth>();
  StreamSubscription? subscription;

  @override
  void onInit() {
    subscription = _auth.authStateChanges().listen((User? user) {
      this.user.value = user;
    });
    super.onInit();
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logOut() async {
    await _auth.signOut();
  }

  @override
  void onClose() {
    subscription?.cancel();
    super.onClose();
  }
}
