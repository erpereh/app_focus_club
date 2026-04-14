import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

import '../../client/domain/portal_models.dart';

abstract interface class AuthRepository {
  Stream<firebase_auth.User?> authStateChanges();
  firebase_auth.User? get currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  Future<void> signInWithGoogle();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<void> signOut();
  Future<void> updatePassword(String password);
  Future<void> updateSafeProfileFields({
    required String uid,
    required String name,
    required String phone,
    String? photoUrl,
  });
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  @override
  firebase_auth.User? get currentUser => _auth.currentUser;

  @override
  Stream<firebase_auth.User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null && !user.emailVerified) {
      await _auth.signOut();
      throw const AuthFailure('email-not-verified');
    }
  }

  @override
  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthFailure('missing-user');
    }

    await user.updateDisplayName(name.trim());
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
          UserProfile(
            uid: user.uid,
            email: email.trim(),
            name: name.trim(),
            phone: phone.trim(),
            role: 'user',
            isTrainer: false,
            createdAt: DateTime.now().toIso8601String(),
          ).toMap(),
        );
    await user.sendEmailVerification();
    await _auth.signOut();
  }

  @override
  Future<void> signInWithGoogle() async {
    await _googleSignIn.initialize();
    final account = await _googleSignIn.authenticate();
    final authentication = account.authentication;
    final credential = firebase_auth.GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return;

    final profileRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await profileRef.get();
    if (!snapshot.exists) {
      await profileRef.set(
        UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          role: 'user',
          isTrainer: false,
          createdAt: DateTime.now().toIso8601String(),
          photoUrl: user.photoURL,
        ).toMap(),
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> updatePassword(String password) async {
    await _auth.currentUser?.updatePassword(password);
  }

  @override
  Future<void> updateSafeProfileFields({
    required String uid,
    required String name,
    required String phone,
    String? photoUrl,
  }) {
    final data = <String, Object?>{'name': name.trim(), 'phone': phone.trim()};
    if (photoUrl != null) data['photoURL'] = photoUrl;
    return _firestore.collection('users').doc(uid).update(data);
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final String code;

  @override
  String toString() => 'AuthFailure($code)';
}
