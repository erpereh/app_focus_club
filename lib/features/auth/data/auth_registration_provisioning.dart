/// Orchestrates Auth + Firestore profile creation without Firebase types.
///
/// A mobile client cannot mathematically guarantee zero orphans: if Firestore
/// fails and `user.delete()` later fails (for example due to network), Auth
/// may still exist. `registration-rollback-failed` surfaces that case; leftover
/// accounts are repaired from the admin web app, not from this client.
class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final String code;

  @override
  String toString() => 'AuthFailure($code)';
}

Future<void> _signOutBestEffort(Future<void> Function() signOut) async {
  try {
    await signOut();
  } catch (_) {}
}

/// Deletes a newly created Auth user after the Firestore profile was not written.
///
/// Cleanup `signOut` is always best-effort so it cannot replace the primary
/// error. If [deleteCreatedUser] itself fails, throws
/// [AuthFailure] `registration-rollback-failed`.
Future<void> rollbackNewAuthUser({
  required Future<void> Function() deleteCreatedUser,
  required Future<void> Function() signOut,
}) async {
  try {
    await deleteCreatedUser();
  } catch (_) {
    await _signOutBestEffort(signOut);
    throw const AuthFailure('registration-rollback-failed');
  }
  await _signOutBestEffort(signOut);
}

/// Email registration: critical phase is create Auth + display name + profile.
///
/// After the profile exists, Auth is never deleted for later failures
/// (verification or the successful-path signOut).
Future<void> runEmailRegistrationProvisioning({
  required Future<void> Function() createAuthUser,
  required Future<void> Function() updateDisplayName,
  required Future<void> Function() writeProfile,
  required Future<void> Function() sendVerification,
  required Future<void> Function() deleteCreatedUser,
  required Future<void> Function() signOut,
}) async {
  var authCreated = false;
  var profileCreated = false;
  var verificationSent = false;
  try {
    await createAuthUser();
    authCreated = true;
    await updateDisplayName();
    await writeProfile();
    profileCreated = true;
    await sendVerification();
    verificationSent = true;
    await signOut();
  } catch (_) {
    if (authCreated && !profileCreated) {
      await rollbackNewAuthUser(
        deleteCreatedUser: deleteCreatedUser,
        signOut: signOut,
      );
      rethrow;
    }
    if (profileCreated && !verificationSent) {
      await _signOutBestEffort(signOut);
      throw const AuthFailure('verification-email-failed');
    }
    rethrow;
  }
}

/// Ensures `users/{uid}` exists after Google sign-in.
///
/// New Auth users (`isNewAuthUser == true`) are deleted if the profile cannot
/// be read or written. Pre-existing Auth users are never deleted.
Future<T> runGoogleProfileProvisioning<T>({
  required bool isNewAuthUser,
  required Future<T?> Function() readExistingProfile,
  required Future<T> Function() createProfile,
  required Future<void> Function() deleteCreatedUser,
  required Future<void> Function() signOut,
}) async {
  try {
    final existing = await readExistingProfile();
    if (existing != null) return existing;
    return await createProfile();
  } catch (_) {
    if (isNewAuthUser) {
      await rollbackNewAuthUser(
        deleteCreatedUser: deleteCreatedUser,
        signOut: signOut,
      );
      rethrow;
    }
    await _signOutBestEffort(signOut);
    rethrow;
  }
}
