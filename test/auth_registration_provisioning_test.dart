import 'package:app_focus_club/features/auth/data/auth_registration_provisioning.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runEmailRegistrationProvisioning', () {
    test(
      'success runs create, displayName, profile, verification, signOut',
      () async {
        final ops = <String>[];

        await runEmailRegistrationProvisioning(
          createAuthUser: () async => ops.add('create'),
          updateDisplayName: () async => ops.add('displayName'),
          writeProfile: () async => ops.add('writeProfile'),
          sendVerification: () async => ops.add('verify'),
          deleteCreatedUser: () async => ops.add('delete'),
          signOut: () async => ops.add('signOut'),
        );

        expect(ops, [
          'create',
          'displayName',
          'writeProfile',
          'verify',
          'signOut',
        ]);
      },
    );

    test('create Auth failure does not delete', () async {
      final ops = <String>[];
      final original = Exception('create-failed');

      await expectLater(
        () => runEmailRegistrationProvisioning(
          createAuthUser: () async {
            ops.add('create');
            throw original;
          },
          updateDisplayName: () async => ops.add('displayName'),
          writeProfile: () async => ops.add('writeProfile'),
          sendVerification: () async => ops.add('verify'),
          deleteCreatedUser: () async => ops.add('delete'),
          signOut: () async => ops.add('signOut'),
        ),
        throwsA(same(original)),
      );

      expect(ops, ['create']);
    });

    test(
      'updateDisplayName failure deletes new Auth and skips profile',
      () async {
        final ops = <String>[];
        final original = Exception('displayName-failed');

        await expectLater(
          () => runEmailRegistrationProvisioning(
            createAuthUser: () async => ops.add('create'),
            updateDisplayName: () async {
              ops.add('displayName');
              throw original;
            },
            writeProfile: () async => ops.add('writeProfile'),
            sendVerification: () async => ops.add('verify'),
            deleteCreatedUser: () async => ops.add('delete'),
            signOut: () async => ops.add('signOut'),
          ),
          throwsA(same(original)),
        );

        expect(ops, ['create', 'displayName', 'delete', 'signOut']);
      },
    );

    test(
      'Firestore profile failure deletes new Auth and skips verification',
      () async {
        final ops = <String>[];
        final original = Exception('profile-failed');

        await expectLater(
          () => runEmailRegistrationProvisioning(
            createAuthUser: () async => ops.add('create'),
            updateDisplayName: () async => ops.add('displayName'),
            writeProfile: () async {
              ops.add('writeProfile');
              throw original;
            },
            sendVerification: () async => ops.add('verify'),
            deleteCreatedUser: () async => ops.add('delete'),
            signOut: () async => ops.add('signOut'),
          ),
          throwsA(same(original)),
        );

        expect(ops, [
          'create',
          'displayName',
          'writeProfile',
          'delete',
          'signOut',
        ]);
      },
    );

    test('successful rollback propagates the original error', () async {
      final original = Exception('profile-failed');

      await expectLater(
        () => runEmailRegistrationProvisioning(
          createAuthUser: () async {},
          updateDisplayName: () async {},
          writeProfile: () async => throw original,
          sendVerification: () async {},
          deleteCreatedUser: () async {},
          signOut: () async {},
        ),
        throwsA(same(original)),
      );
    });

    test(
      'delete failure during rollback signs out and throws rollback-failed',
      () async {
        final ops = <String>[];

        await expectLater(
          () => runEmailRegistrationProvisioning(
            createAuthUser: () async => ops.add('create'),
            updateDisplayName: () async {},
            writeProfile: () async => throw Exception('profile-failed'),
            sendVerification: () async => ops.add('verify'),
            deleteCreatedUser: () async {
              ops.add('delete');
              throw Exception('delete-failed');
            },
            signOut: () async => ops.add('signOut'),
          ),
          throwsA(
            isA<AuthFailure>().having(
              (error) => error.code,
              'code',
              'registration-rollback-failed',
            ),
          ),
        );

        expect(ops, ['create', 'delete', 'signOut']);
      },
    );

    test(
      'delete and cleanup signOut both failing still throw registration-rollback-failed',
      () async {
        final ops = <String>[];

        await expectLater(
          () => runEmailRegistrationProvisioning(
            createAuthUser: () async => ops.add('create'),
            updateDisplayName: () async {},
            writeProfile: () async => throw Exception('profile-failed'),
            sendVerification: () async => ops.add('verify'),
            deleteCreatedUser: () async {
              ops.add('delete');
              throw Exception('delete-failed');
            },
            signOut: () async {
              ops.add('signOut');
              throw Exception('signOut-failed');
            },
          ),
          throwsA(
            isA<AuthFailure>().having(
              (error) => error.code,
              'code',
              'registration-rollback-failed',
            ),
          ),
        );

        expect(ops, ['create', 'delete', 'signOut']);
      },
    );

    test(
      'successful delete with failing cleanup signOut still propagates original error',
      () async {
        final original = Exception('profile-failed');

        await expectLater(
          () => runEmailRegistrationProvisioning(
            createAuthUser: () async {},
            updateDisplayName: () async {},
            writeProfile: () async => throw original,
            sendVerification: () async {},
            deleteCreatedUser: () async {},
            signOut: () async => throw Exception('signOut-failed'),
          ),
          throwsA(same(original)),
        );
      },
    );

    test(
      'verification failure after profile does not delete and maps to verification-email-failed',
      () async {
        final ops = <String>[];

        await expectLater(
          () => runEmailRegistrationProvisioning(
            createAuthUser: () async => ops.add('create'),
            updateDisplayName: () async => ops.add('displayName'),
            writeProfile: () async => ops.add('writeProfile'),
            sendVerification: () async {
              ops.add('verify');
              throw Exception('verify-failed');
            },
            deleteCreatedUser: () async => ops.add('delete'),
            signOut: () async => ops.add('signOut'),
          ),
          throwsA(
            isA<AuthFailure>().having(
              (error) => error.code,
              'code',
              'verification-email-failed',
            ),
          ),
        );

        expect(ops, [
          'create',
          'displayName',
          'writeProfile',
          'verify',
          'signOut',
        ]);
      },
    );

    test(
      'verification failure still maps even if cleanup signOut fails',
      () async {
        final ops = <String>[];

        await expectLater(
          () => runEmailRegistrationProvisioning(
            createAuthUser: () async => ops.add('create'),
            updateDisplayName: () async {},
            writeProfile: () async => ops.add('writeProfile'),
            sendVerification: () async {
              ops.add('verify');
              throw Exception('verify-failed');
            },
            deleteCreatedUser: () async => ops.add('delete'),
            signOut: () async {
              ops.add('signOut');
              throw Exception('signOut-failed');
            },
          ),
          throwsA(
            isA<AuthFailure>().having(
              (error) => error.code,
              'code',
              'verification-email-failed',
            ),
          ),
        );

        expect(ops, ['create', 'writeProfile', 'verify', 'signOut']);
        expect(ops, isNot(contains('delete')));
      },
    );

    test(
      'successful-path signOut failure after profile does not delete',
      () async {
        final ops = <String>[];
        final original = Exception('signOut-failed');

        await expectLater(
          () => runEmailRegistrationProvisioning(
            createAuthUser: () async => ops.add('create'),
            updateDisplayName: () async => ops.add('displayName'),
            writeProfile: () async => ops.add('writeProfile'),
            sendVerification: () async => ops.add('verify'),
            deleteCreatedUser: () async => ops.add('delete'),
            signOut: () async {
              ops.add('signOut');
              throw original;
            },
          ),
          throwsA(same(original)),
        );

        expect(ops, [
          'create',
          'displayName',
          'writeProfile',
          'verify',
          'signOut',
        ]);
      },
    );
  });

  group('runGoogleProfileProvisioning', () {
    test('new user profile failure deletes Auth and signs out', () async {
      final ops = <String>[];
      final original = Exception('profile-failed');

      await expectLater(
        () => runGoogleProfileProvisioning<String>(
          isNewAuthUser: true,
          readExistingProfile: () async {
            ops.add('read');
            return null;
          },
          createProfile: () async {
            ops.add('writeProfile');
            throw original;
          },
          deleteCreatedUser: () async => ops.add('delete'),
          signOut: () async => ops.add('signOut'),
        ),
        throwsA(same(original)),
      );

      expect(ops, ['read', 'writeProfile', 'delete', 'signOut']);
    });

    test(
      'existing user profile failure never deletes and keeps original error',
      () async {
        final ops = <String>[];
        final original = Exception('profile-failed');

        await expectLater(
          () => runGoogleProfileProvisioning<String>(
            isNewAuthUser: false,
            readExistingProfile: () async {
              ops.add('read');
              return null;
            },
            createProfile: () async {
              ops.add('writeProfile');
              throw original;
            },
            deleteCreatedUser: () async => ops.add('delete'),
            signOut: () async => ops.add('signOut'),
          ),
          throwsA(same(original)),
        );

        expect(ops, ['read', 'writeProfile', 'signOut']);
      },
    );

    test(
      'existing user keeps original Firestore error if cleanup signOut fails',
      () async {
        final original = Exception('profile-failed');

        await expectLater(
          () => runGoogleProfileProvisioning<String>(
            isNewAuthUser: false,
            readExistingProfile: () async => null,
            createProfile: () async => throw original,
            deleteCreatedUser: () async {},
            signOut: () async => throw Exception('signOut-failed'),
          ),
          throwsA(same(original)),
        );
      },
    );

    test('successful profile create does not delete', () async {
      final ops = <String>[];

      final profile = await runGoogleProfileProvisioning<String>(
        isNewAuthUser: true,
        readExistingProfile: () async {
          ops.add('read');
          return null;
        },
        createProfile: () async {
          ops.add('writeProfile');
          return 'created';
        },
        deleteCreatedUser: () async => ops.add('delete'),
        signOut: () async => ops.add('signOut'),
      );

      expect(profile, 'created');
      expect(ops, ['read', 'writeProfile']);
    });

    test('existing profile is returned without write or delete', () async {
      final ops = <String>[];

      final profile = await runGoogleProfileProvisioning<String>(
        isNewAuthUser: true,
        readExistingProfile: () async {
          ops.add('read');
          return 'existing';
        },
        createProfile: () async {
          ops.add('writeProfile');
          return 'created';
        },
        deleteCreatedUser: () async => ops.add('delete'),
        signOut: () async => ops.add('signOut'),
      );

      expect(profile, 'existing');
      expect(ops, ['read']);
    });
  });

  group('authErrorMessage', () {
    test('maps registration-rollback-failed', () {
      expect(
        authErrorMessage(const AuthFailure('registration-rollback-failed')),
        'No hemos podido completar el registro. Inténtalo de nuevo o contacta con Focus Club.',
      );
    });

    test('maps verification-email-failed', () {
      expect(
        authErrorMessage(const AuthFailure('verification-email-failed')),
        'Tu cuenta se ha creado, pero no hemos podido enviar el email de verificación. Inicia sesión para volver a solicitarlo.',
      );
    });

    test('keeps existing email-not-verified copy', () {
      expect(
        authErrorMessage(const AuthFailure('email-not-verified')),
        'Tu email aun no esta verificado. Te hemos enviado un nuevo enlace.',
      );
    });
  });
}
