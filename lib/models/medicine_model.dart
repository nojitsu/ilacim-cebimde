import 'package:cloud_firestore/cloud_firestore.dart';

class IlacModel {
  final String id;
  final String name;
  final String dose;
  final List<String> times; // Kullanım saatleri (HH:mm formatında)
  final int totalQuantity; // Toplam ilaç adedi
  final int remainingQuantity; // Kalan ilaç adedi
  final DateTime createdAt;
  final String? audioPath;

  IlacModel({
    required this.id,
    required this.name,
    required this.dose,
    required this.times,
    this.totalQuantity = 0, // 0 = sınırsız
    int? remainingQuantity,
    DateTime? createdAt,
    this.audioPath,
  })  : remainingQuantity = remainingQuantity ?? totalQuantity,
        createdAt = createdAt ?? DateTime.now();

  /// Günlük kullanım sayısı
  int get frequency => times.length;

  /// İlaç bitti mi?
  bool get isEmpty => totalQuantity > 0 && remainingQuantity <= 0;

  /// İlaç stok durumu yüzdesi
  double get stockPercentage {
    if (totalQuantity == 0) return 1.0; // Sınırsız
    return remainingQuantity / totalQuantity;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dose': dose,
      'times': times,
      'totalQuantity': totalQuantity,
      'remainingQuantity': remainingQuantity,
      'createdAt': Timestamp.fromDate(createdAt.toUtc()),
      'audioPath': audioPath,
    };
  }

  factory IlacModel.fromMap(Map<String, dynamic> map, String id) {
    // times alanını parse et
    List<String> parsedTimes = [];
    if (map['times'] != null) {
      parsedTimes = List<String>.from(map['times']);
    } else if (map['startDate'] != null) {
      // Eski format desteği - startDate ve frequency varsa dönüştür
      final dynamic start = map['startDate'];
      DateTime startDate;
      if (start is Timestamp) {
        startDate = start.toDate();
      } else if (start is String) {
        startDate = DateTime.parse(start);
      } else {
        startDate = DateTime.now();
      }

      final int freq = (map['frequency'] is int)
          ? map['frequency'] as int
          : int.tryParse('${map['frequency']}') ?? 1;

      // Eski formatı yeni formata çevir
      for (int i = 0; i < freq; i++) {
        final int hourOffset = (24 ~/ freq) * i;
        final int hour = (startDate.hour + hourOffset) % 24;
        parsedTimes.add(
            '${hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}');
      }
    }

    // createdAt parse et
    DateTime parsedCreatedAt = DateTime.now();
    final dynamic created = map['createdAt'];
    if (created is Timestamp) {
      parsedCreatedAt = created.toDate();
    } else if (created is String) {
      parsedCreatedAt = DateTime.parse(created);
    }

    return IlacModel(
      id: id,
      name: map['name'] ?? '',
      dose: map['dose'] ?? '',
      times: parsedTimes,
      totalQuantity: map['totalQuantity'] ?? 0,
      remainingQuantity: map['remainingQuantity'] ?? map['totalQuantity'] ?? 0,
      createdAt: parsedCreatedAt,
      audioPath: map['audioPath'],
    );
  }

  /// Kopyala ve değiştir
  IlacModel copyWith({
    String? id,
    String? name,
    String? dose,
    List<String>? times,
    int? totalQuantity,
    int? remainingQuantity,
    DateTime? createdAt,
    String? audioPath,
  }) {
    return IlacModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      times: times ?? this.times,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      createdAt: createdAt ?? this.createdAt,
      audioPath: audioPath ?? this.audioPath,
    );
  }
}
