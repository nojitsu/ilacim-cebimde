import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/history_model.dart';

class HistoryService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  CollectionReference get _historyCollection {
    if (currentUser == null) throw Exception("Kullanıcı girişi yapılmamış.");
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('history');
  }

  Future<void> addHistory(HistoryModel history) async {
    if (currentUser == null) return;
    await _historyCollection.add(history.toMap());
    notifyListeners();
  }

  Stream<List<HistoryModel>> getHistoryForDay(DateTime day) {
    if (currentUser == null) return Stream.value([]);

    final localStartOfDay = DateTime(day.year, day.month, day.day);
    final startOfUtc = localStartOfDay.toUtc();
    final endOfUtc = startOfUtc.add(const Duration(days: 1));

    return _historyCollection
        .where('takenAt', isGreaterThanOrEqualTo: startOfUtc)
        .where('takenAt', isLessThan: endOfUtc)
        .orderBy('takenAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => HistoryModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    });
  }
}
