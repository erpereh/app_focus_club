import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

abstract interface class AvatarStorageRepository {
  Future<String> uploadAvatar({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> deleteAvatarByPath(String storagePath);
  Future<void> deleteAvatarByUrl(String photoUrl);
}

class FirebaseAvatarStorageRepository implements AvatarStorageRepository {
  FirebaseAvatarStorageRepository({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadAvatar({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'user-avatars/$uid/$safeFileName';
    final ref = _storage.ref(path);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return task.ref.getDownloadURL();
  }

  @override
  Future<void> deleteAvatarByPath(String storagePath) {
    return _storage.ref(storagePath).delete();
  }

  @override
  Future<void> deleteAvatarByUrl(String photoUrl) async {
    if (photoUrl.trim().isEmpty) return;
    try {
      await _storage.refFromURL(photoUrl).delete();
    } on FirebaseException {
      // Avatar cleanup should not block saving the new profile photo.
    }
  }
}
