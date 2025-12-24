import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine_model.dart';
import '../models/medicine_intake_model.dart';
import 'notification_service.dart';

class MedicineService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService;

  MedicineService(this._notificationService);

  User? get currentUser => FirebaseAuth.instance.currentUser;

  CollectionReference get _medicineCollection {
    if (currentUser == null) throw Exception("Kullanıcı girişi yapılmamış.");
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('medicines');
  }

  CollectionReference get _intakeCollection {
    if (currentUser == null) throw Exception("Kullanıcı girişi yapılmamış.");
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('intakes');
  }

  Future<void> addMedicine(IlacModel medicine) async {
    if (currentUser == null) return;
    final docRef = await _medicineCollection.add(medicine.toMap());

    // Yeni oluşturulan ID ile modeli güncelle
    final newMed = medicine.copyWith(id: docRef.id);

    // Bildirimleri zamanla
    await _notificationService.scheduleMedicineNotifications(newMed);
    notifyListeners();
  }

  Future<void> updateMedicine(IlacModel medicine) async {
    if (currentUser == null) return;
    await _medicineCollection.doc(medicine.id).update(medicine.toMap());

    // Bildirimleri güncelle
    await _notificationService.scheduleMedicineNotifications(medicine);
    notifyListeners();
  }

  Future<void> deleteMedicine(String id) async {
    if (currentUser == null) return;
    await _medicineCollection.doc(id).delete();

    // Bildirimleri iptal et
    await _notificationService.cancelMedicineNotifications(id);
    notifyListeners();
  }

  Stream<List<IlacModel>> getMedicines() {
    if (currentUser == null) return Stream.value([]);
    return _medicineCollection
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map(
            (d) => IlacModel.fromMap(d.data() as Map<String, dynamic>, d.id),
          )
          .toList();
    });
  }

  /// İlaç kullanıldığında stoktan düşür ve alım kaydı oluştur
  Future<bool> takeMedicine(
    IlacModel medicine, {
    String? scheduledTime,
    DateTime? scheduledDate,
  }) async {
    if (currentUser == null) return false;

    if (currentUser == null) return false;

    // DATABASE'DEN GÜNCEL VERİYİ ÇEK (EKSİK MODEL HATASINI ÖNLEMEK İÇİN)
    // Alarm ekranından gelen modelde totalQuantity/remainingQuantity bilgisi olmayabilir (varsayılan 0 gelir).
    // Bu yüzden "sınırsız stok" sanılabilir. Doğrusu: Veritabanından okumak.
    final docSnapshot = await _medicineCollection.doc(medicine.id).get();
    if (!docSnapshot.exists) {
      // İlaç silinmiş olabilir
      return false;
    }

    final currentMedicine = IlacModel.fromMap(
      docSnapshot.data() as Map<String, dynamic>,
      docSnapshot.id,
    );

    // Sınırsız stok kontrolü (Veritabanındaki gerçek veriye göre)
    if (currentMedicine.totalQuantity == 0) {
      await _recordIntake(currentMedicine, scheduledTime, scheduledDate);
      return true; // Sınırsız, alım başarılı
    }

    // Stok kontrolü
    if (currentMedicine.remainingQuantity <= 0) {
      return false; // Stok bitti
    }

    // Kalan miktarı azalt
    final updatedMedicine = currentMedicine.copyWith(
      remainingQuantity: currentMedicine.remainingQuantity - 1,
    );

    // Batch işlemi: Hem ilacı güncelle hem de intake kaydı oluştur
    final batch = _firestore.batch();

    // 1. İlaç güncelleme
    final medRef = _medicineCollection.doc(currentMedicine.id);
    batch.update(medRef, {
      'remainingQuantity': updatedMedicine.remainingQuantity,
    });

    // 2. Intake kaydı oluşturma
    await _recordIntake(currentMedicine, scheduledTime, scheduledDate,
        batch: batch);

    await batch.commit();

    notifyListeners();
    return true;
  }

  /// Alım kaydı oluştur (Yardımcı metod)
  Future<void> _recordIntake(
    IlacModel medicine,
    String? scheduledTime,
    DateTime? scheduledDate, {
    WriteBatch? batch,
  }) async {
    final now = DateTime.now();
    final intakeData = MedicineIntakeModel(
      id: '', // Firestore oluşturacak
      medicineId: medicine.id,
      medicineName: medicine.name,
      dose: medicine.dose,
      scheduledTime: scheduledTime ?? '${now.hour}:${now.minute}',
      scheduledDate: scheduledDate ?? DateTime(now.year, now.month, now.day),
      takenAt: now,
      status: 'taken',
    ).toMap();

    // ID'yi tarih ve saate göre oluştur ki aynı dozu 2 kere almayalım
    final dateStr = (scheduledDate ?? now).toIso8601String().split('T')[0];
    final timeStr = scheduledTime ?? '${now.hour}:${now.minute}';
    final docId = '${medicine.id}_${dateStr}_$timeStr';

    final docRef = _intakeCollection.doc(docId);

    if (batch != null) {
      batch.set(docRef, intakeData);
    } else {
      await docRef.set(intakeData);
    }
  }

  /// Belirli bir gün için alım kayıtlarını getir
  Stream<List<MedicineIntakeModel>> getIntakesForDay(DateTime date) {
    if (currentUser == null) return Stream.value([]);

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _intakeCollection
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        return MedicineIntakeModel.fromMap(
          d.data() as Map<String, dynamic>,
          d.id,
        );
      }).toList();
    });
  }

  /// Stok ekle (yeniden doldurma)
  Future<void> refillMedicine(String medicineId, int amount) async {
    if (currentUser == null) return;

    final doc = await _medicineCollection.doc(medicineId).get();
    if (!doc.exists) return;

    final medicine =
        IlacModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final newQuantity = medicine.remainingQuantity + amount;

    await _medicineCollection.doc(medicineId).update({
      'remainingQuantity': newQuantity,
      'totalQuantity': newQuantity > medicine.totalQuantity
          ? newQuantity
          : medicine.totalQuantity,
    });

    notifyListeners();
  }

  /// Belirli bir ilaç için son alınma zamanını getir
  Future<DateTime?> getLastIntake(String medicineId) async {
    if (currentUser == null) return null;

    final query = await _intakeCollection
        .where('medicineId', isEqualTo: medicineId)
        .where('status', isEqualTo: 'taken')
        .orderBy('takenAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final data = query.docs.first.data() as Map<String, dynamic>;
    if (data['takenAt'] == null) return null;

    return (data['takenAt'] as Timestamp).toDate();
  }
}
