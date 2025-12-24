import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryModel {
  final String id;
  final String medicineId;
  final String medicineName;
  final String dose;
  final DateTime takenAt;

  HistoryModel({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.dose,
    required this.takenAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dose': dose,
      'takenAt': Timestamp.fromDate(takenAt.toUtc()),
    };
  }

  factory HistoryModel.fromMap(Map<String, dynamic> map, String id) {
    final dynamic taken = map['takenAt'];
    DateTime parsed;
    if (taken is Timestamp) {
      parsed = taken.toDate();
    } else if (taken is String) {
      parsed = DateTime.parse(taken);
    } else {
      parsed = DateTime.now();
    }

    return HistoryModel(
      id: id,
      medicineId: map['medicineId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      dose: map['dose'] ?? '',
      takenAt: parsed,
    );
  }
}
