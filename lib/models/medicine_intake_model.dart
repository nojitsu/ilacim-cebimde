import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineIntakeModel {
  final String id;
  final String medicineId;
  final String medicineName;
  final String dose;
  final String scheduledTime; // "08:00" gibi
  final DateTime scheduledDate; // Hangi gün için
  final DateTime? takenAt; // Ne zaman alındı
  final String status; // 'taken', 'missed', 'snoozed', 'skipped'

  MedicineIntakeModel({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.dose,
    required this.scheduledTime,
    required this.scheduledDate,
    this.takenAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dose': dose,
      'scheduledTime': scheduledTime,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'takenAt': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
      'status': status,
    };
  }

  factory MedicineIntakeModel.fromMap(Map<String, dynamic> map, String id) {
    return MedicineIntakeModel(
      id: id,
      medicineId: map['medicineId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      dose: map['dose'] ?? '',
      scheduledTime: map['scheduledTime'] ?? '',
      scheduledDate: (map['scheduledDate'] as Timestamp).toDate(),
      takenAt: map['takenAt'] != null
          ? (map['takenAt'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'pending',
    );
  }
}
