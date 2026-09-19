import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/media_item.dart';

class CloudSyncService {
  CloudSyncService._();
  static final instance = CloudSyncService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> syncLibrary(List<MediaItem> localItems) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid).collection('library');
    final snapshot = await ref.get();
    final remote = <String, MediaItem>{};
    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      remote['${data['media_type']}:${data['id']}'] = MediaItem.fromJson(data);
    }
    final merged = <String, MediaItem>{...remote};
    for (final item in localItems) {
      merged['${item.mediaType}:${item.id}'] = item;
    }
    final batch = _db.batch();
    for (final item in merged.values) {
      final key = '${item.mediaType}:${item.id}';
      batch.set(ref.doc(key), item.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<List<MediaItem>> downloadLibrary() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snapshot = await _db.collection('users').doc(user.uid).collection('library').get();
    return snapshot.docs
        .map((doc) => MediaItem.fromJson(Map<String, dynamic>.from(doc.data())))
        .toList();
  }
}
