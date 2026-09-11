import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

import '../../client/domain/portal_models.dart';
import 'auth_registration_provisioning.dart';

export 'auth_registration_provisioning.dart' show AuthFailure;

abstract interface class AuthRepository {
  Stream<AuthSession?> authStateChanges();
  AuthSession? get currentSession;

  Future<AuthGateResult> resolveAuthGate();

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

  Future<GoogleAuthResult> signInWithGoogle();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<void> resendEmailVerification({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<void> updatePassword(String password);
  Future<void> updateSafeProfileFields({
    required String uid,
    required String name,
    required String phone,
    String? photoUrl,
  });
}

enum AuthGateResult { signedOut, needsGoogleProfile, signedIn }

class AuthSession {
  const AuthSession({
    required this.uid,
    required this.isEmailVerified,
    required this.canChangePassword,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isEmailVerified;
  final bool canChangePassword;
}

enum GoogleAuthStatus { signedIn, needsProfile }

class GoogleAuthResult {
  const GoogleAuthResult({required this.status, required this.session});

  final GoogleAuthStatus status;
  final AuthSession session;
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
  Future<void>? _googleSignInInitialization;

  @override
  AuthSession? get currentSession => _auth.currentUser?.toAuthSession();

  @override
  Stream<AuthSession?> authStateChanges() {
    return _auth.authStateChanges().map((user) => user?.toAuthSession());
  }

  @override
  Future<AuthGateResult> resolveAuthGate() async {
    final user = _auth.currentUser;
    if (user == null) return AuthGateResult.signedOut;
    if (!user.emailVerified) {
      await _auth.signOut();
      return AuthGateResult.signedOut;
    }
    final profile = await _userProfile(user.uid);
    if (profile != null && !_hasPhone(profile)) {
      return AuthGateResult.needsGoogleProfile;
    }
    return AuthGateResult.signedIn;
  }

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
      await user.sendEmailVerification();
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
    firebase_auth.User? createdUser;
    await runEmailRegistrationProvisioning(
      createAuthUser: () async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        createdUser = credential.user;
        if (createdUser == null) {
          throw const AuthFailure('missing-user');
        }
      },
      updateDisplayName: () => createdUser!.updateDisplayName(name.trim()),
      writeProfile: () {
        final user = createdUser!;
        return _firestore
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
      },
      sendVerification: () => createdUser!.sendEmailVerification(),
      deleteCreatedUser: () => createdUser!.delete(),
      signOut: () => _auth.signOut(),
    );
  }

  @override
  Future<GoogleAuthResult> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    final account = await _googleSignIn.authenticate();
    final authentication = account.authentication;
    final credential = firebase_auth.GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw const AuthFailure('missing-user');
    }

    final isNewAuthUser = userCredential.additionalUserInfo?.isNewUser == true;
    final profileRef = _firestore.collection('users').doc(user.uid);
    final profile = await runGoogleProfileProvisioning<UserProfile>(
      isNewAuthUser: isNewAuthUser,
      readExistingProfile: () async {
        final snapshot = await profileRef.get();
        if (!snapshot.exists) return null;
        return UserProfile.fromMap(snapshot.data()!);
      },
      createProfile: () async {
        final created = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          role: 'user',
          isTrainer: false,
          createdAt: DateTime.now().toIso8601String(),
          photoUrl: user.photoURL,
        );
        await profileRef.set(created.toMap());
        return created;
      },
      deleteCreatedUser: () => user.delete(),
      signOut: () => _auth.signOut(),
    );

    return GoogleAuthResult(
      status: _hasPhone(profile)
          ? GoogleAuthStatus.signedIn
          : GoogleAuthStatus.needsProfile,
      session: user.toAuthSession(),
    );
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
  Future<void> resendEmailVerification({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.sendEmailVerification();
    await _auth.signOut();
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase Auth is the source of truth for app access.
    }
    await _auth.signOut();
  }

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

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= _googleSignIn.initialize();
  }

  Future<UserProfile?> _userProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  bool _hasPhone(UserProfile profile) {
    return (profile.phone ?? '').trim().isNotEmpty;
  }
}

extension on firebase_auth.User {
  AuthSession toAuthSession() {
    return AuthSession(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoURL,
      isEmailVerified: emailVerified,
      canChangePassword: providerData.any(
        (provider) => provider.providerId == 'password',
      ),
    );
  }
}

String authErrorMessage(Object error) {
  if (error is AuthFailure) {
    return switch (error.code) {
      'email-not-verified' =>
        'Tu email aun no esta verificado. Te hemos enviado un nuevo enlace.',
      'missing-user' => 'No hemos podido recuperar la sesion de usuario.',
      'registration-rollback-failed' =>
        'No hemos podido completar el registro. Inténtalo de nuevo o contacta con Focus Club.',
      'verification-email-failed' =>
        'Tu cuenta se ha creado, pero no hemos podido enviar el email de verificación. Inicia sesión para volver a solicitarlo.',
      _ => 'No hemos podido completar la autenticacion.',
    };
  }
  if (error is firebase_auth.FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email o contrasena incorrectos.',
      'email-already-in-use' => 'Ya existe una cuenta con este email.',
      'invalid-email' => 'Introduce un email valido.',
      'weak-password' => 'La contrasena debe tener al menos 8 caracteres.',
      'network-request-failed' =>
        'No hay conexion. Revisa la red e intentalo de nuevo.',
      'operation-not-allowed' =>
        'Este proveedor de autenticacion no esta habilitado en Firebase.',
      'requires-recent-login' =>
        'Por seguridad, vuelve a iniciar sesion antes de cambiar la contrasena.',
      _ => 'No hemos podido completar la autenticacion. Intentalo de nuevo.',
    };
  }
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Inicio con Google cancelado.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Falta configuracion de Google Sign-In en Firebase o en la app.',
      _ => 'No hemos podido iniciar sesion con Google.',
    };
  }
  return 'No hemos podido completar la autenticacion. Intentalo de nuevo.';
}
