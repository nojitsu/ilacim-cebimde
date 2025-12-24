import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/medicine_model.dart';
import '../models/medicine_intake_model.dart';
import '../services/medicine_service.dart';
import 'add_medicine_screen.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  Timer? _timer;
  Key _refreshKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Burada setState ile key'i değiştirerek alt widget'ların
    // yeniden build edilmesini ve verileri tazelemelerini sağlıyoruz
    setState(() {
      _refreshKey = UniqueKey();
    });
    // Simüle edilmiş bir bekleme (kullanıcı yenilendiğini hissetsin)
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MedicineService>(context, listen: false);

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: MultiProvider(
        providers: [
          StreamProvider<List<IlacModel>>(
            create: (_) => service.getMedicines(),
            initialData: const [],
          ),
          StreamProvider<List<MedicineIntakeModel>>(
            create: (_) => service.getIntakesForDay(DateTime.now()),
            initialData: const [],
          ),
        ],
        builder: (context, child) {
          final medicines = Provider.of<List<IlacModel>>(context);
          final dailyIntakes = Provider.of<List<MedicineIntakeModel>>(context);

          // Stream'ler henüz yükleniyor mu diye basit bir kontrol (boş liste gelebilir)
          // Ancak MedicineService streami boş liste dönebilir, bu yüzden
          // loading state'i yerine veriye odaklanıyoruz.

          if (medicines.isEmpty) {
            // İlaç yoksa veya yükleniyorsa
            return ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication,
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz ilaç eklenmedi',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sağ üstteki + butonuna tıklayarak\nilaç ekleyebilirsiniz',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            key: _refreshKey,
            padding: const EdgeInsets.all(8),
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              final med = medicines[index];
              return _MedicineCard(
                medicine: med,
                service: service,
                todaysIntakes: dailyIntakes,
              );
            },
          );
        },
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final IlacModel medicine;
  final MedicineService service;
  final List<MedicineIntakeModel> todaysIntakes;

  const _MedicineCard({
    required this.medicine,
    required this.service,
    required this.todaysIntakes,
  });

  @override
  Widget build(BuildContext context) {
    return _MedicineCardContent(
      medicine: medicine,
      service: service,
      todaysIntakes: todaysIntakes,
    );
  }
}

class _MedicineCardContent extends StatefulWidget {
  final IlacModel medicine;
  final MedicineService service;
  final List<MedicineIntakeModel> todaysIntakes;

  const _MedicineCardContent({
    required this.medicine,
    required this.service,
    required this.todaysIntakes,
  });

  @override
  State<_MedicineCardContent> createState() => _MedicineCardContentState();
}

class _MedicineCardContentState extends State<_MedicineCardContent> {
  DateTime? _lastTakenDate;

  @override
  void initState() {
    super.initState();
    _loadLastTaken();
  }

  @override
  void didUpdateWidget(covariant _MedicineCardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Eğer dışarıdan bir tetikleme ile (örn refresh) widget yenilenirse
    // son veriyi tekrar çek.
    if (oldWidget.medicine.id != widget.medicine.id) {
      _loadLastTaken();
    }
  }

  void _loadLastTaken() async {
    final date = await widget.service.getLastIntake(widget.medicine.id);
    if (mounted) {
      setState(() => _lastTakenDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicine = widget.medicine;

    // Bir sonraki dozu, alınanları göz ardı ederek hesapla
    final nextDoseInfo = _getNextDose(medicine, widget.todaysIntakes);
    final String? nextDose = nextDoseInfo['time'];
    final bool isOverdue = nextDoseInfo['isOverdue'] == true;
    final bool isTomorrow = nextDoseInfo['isTomorrow'] == true;

    // "Bugün bitti" kontrolünü artık NextDose içinde isTomorrow ile anlıyoruz
    // Ancak nextDose null ise (tüm zamanlar bitti ve yarın da yoksa?) -> Tamamlandı
    // Bu durumda isTakenToday kullanımı sadece eski mantık için kalabilir veya nextDose == null ise bitti diyebiliriz.

    final countdown = _getCountdown(nextDose, isTomorrow: isTomorrow);
    // isOverdue zaten nextDoseInfo'dan geliyor

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddMedicineScreen(medicine: medicine),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve silme butonu
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    radius: 24,
                    child: const Icon(Icons.medication,
                        color: Colors.blue, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          medicine.dose,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _showDeleteDialog(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Geri Sayım Widget'ı
              if (nextDose != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getCountdownColor(countdown)
                            .withOpacity(isOverdue ? 0.2 : 0.1),
                        _getCountdownColor(countdown)
                            .withOpacity(isOverdue ? 0.1 : 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _getCountdownColor(countdown).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTomorrow
                            ? Icons.calendar_today_outlined
                            : Icons.timer_outlined,
                        color: _getCountdownColor(countdown),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOverdue
                                  ? 'İlaç Saati Geçti!'
                                  : (isTomorrow
                                      ? 'Sonraki Doz (Yarın)'
                                      : 'Sonraki doz: $nextDose'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverdue
                                    ? Colors.red[900]
                                    : Colors.grey[600],
                                fontWeight: isOverdue
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              countdown,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _getCountdownColor(countdown),
                              ),
                            ),
                            if (isOverdue)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text("Hemen almalısın!",
                                    style: TextStyle(
                                        color: Colors.red[800], fontSize: 10)),
                              )
                          ],
                        ),
                      ),
                      _buildStatusIcon(countdown),
                    ],
                  ),
                )
              else
                // Hiç doz yoksa veya bir şekilde hesaplanamadıysa (Tamamlandı)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Tüm dozlar tamamlandı!',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // Kullanım saatleri ve Son Alınan
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Program: ',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: medicine.times.map((time) {
                            final isNext = time == nextDose && !isOverdue;
                            final isTaken = _isTimeTaken(
                                medicine.id, time, widget.todaysIntakes);

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isTaken
                                    ? Colors.green[100] // Alındıysa açık yeşil
                                    : (isNext
                                        ? Colors.blue // Sıradakiyse mavi
                                        : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(12),
                                border: isNext
                                    ? null
                                    : Border.all(
                                        color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isNext
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      decoration: isTaken
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isNext
                                          ? Colors.white
                                          : (isTaken
                                              ? Colors.green[800]
                                              : Colors.grey[700]),
                                    ),
                                  ),
                                  if (isTaken) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.check,
                                        size: 12, color: Colors.green[800]),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  if (_lastTakenDate != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Son alınan: ',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                              const Icon(Icons.history,
                                  size: 14, color: Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatLastTaken(_lastTakenDate!),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Stok Göstergesi
              if (medicine.totalQuantity > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStockColor(medicine.stockPercentage)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStockColor(medicine.stockPercentage)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: _getStockColor(medicine.stockPercentage),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Stok Durumu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${medicine.remainingQuantity}/${medicine.totalQuantity}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _getStockColor(
                                        medicine.stockPercentage),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: medicine.stockPercentage,
                                backgroundColor: Colors.grey[200],
                                color: _getStockColor(medicine.stockPercentage),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // İlaç Al Butonu
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: medicine.isEmpty || isTomorrow || nextDose == null
                      ? null // Stok yoksa, yarınsa veya sıradaki doz yoksa pasif
                      : () => _takeMedicine(context, nextDose),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text(
                    medicine.isEmpty
                        ? 'Stok Bitti'
                        : (isOverdue
                            ? 'Gecikmiş İlacı Al'
                            : (isTomorrow ? 'Yarın Alınacak' : 'İlacı Aldım')),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: medicine.isEmpty
                        ? Colors.grey
                        : (isOverdue
                            ? Colors.red
                            : (isTomorrow ? Colors.blue : Colors.green)),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStockColor(double percentage) {
    if (percentage > 0.5) return Colors.green;
    if (percentage > 0.2) return Colors.orange;
    return Colors.red;
  }

  Future<void> _takeMedicine(
      BuildContext context, String? scheduledTime) async {
    // scheduledTime null ise (zor bir ihtimal ama) şu anki saati kullan
    final now = DateTime.now();
    final timeStr = scheduledTime ?? '${now.hour}:${now.minute}';

    final success = await widget.service.takeMedicine(
      widget.medicine,
      scheduledTime: timeStr,
      scheduledDate: now,
    );

    if (context.mounted) {
      if (success) {
        // Son alım tarihini güncelle
        _loadLastTaken();
        // UI Stream sayesinde otomatik güncellenecek

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.medicine.name} alındı ✓'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.medicine.name} stokta yok!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLastTaken(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Bugün ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays == 1) {
      return 'Dün ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd.MM HH:mm').format(date);
    }
  }

  // --- Yardımcı Metodlar ---

  bool _isTimeTaken(
      String medId, String time, List<MedicineIntakeModel> intakes) {
    return intakes.any((i) =>
        i.medicineId == medId &&
        i.scheduledTime == time &&
        i.status == 'taken');
  }

  /// Sonraki dozu ve durumunu bul
  /// Return: {'time': String?, 'isOverdue': bool, 'isTomorrow': bool}
  Map<String, dynamic> _getNextDose(
      IlacModel med, List<MedicineIntakeModel> intakes) {
    if (med.times.isEmpty) return {'time': null};

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // Zamanları dakika cinsinden sırala
    final sortedTimes = [...med.times];
    sortedTimes.sort((a, b) {
      final pa = a.split(':').map(int.parse).toList();
      final pb = b.split(':').map(int.parse).toList();
      return (pa[0] * 60 + pa[1]).compareTo(pb[0] * 60 + pb[1]);
    });

    // 1. Henüz alınmamış ilk zamanı bul (bugün için)
    for (final time in sortedTimes) {
      if (_isTimeTaken(med.id, time, intakes)) continue; // Alınmış, geç

      final parts = time.split(':').map(int.parse).toList();
      final timeMinutes = parts[0] * 60 + parts[1];

      // Eğer saati geçmişse -> Gecikmiş (Overdue)
      if (currentMinutes > timeMinutes) {
        return {'time': time, 'isOverdue': true, 'isTomorrow': false};
      }
      // Eğer saati henüz gelmemişse -> Sıradaki (Next)
      return {'time': time, 'isOverdue': false, 'isTomorrow': false};
    }

    // 2. Bugün hepsi alınmışsa, yarının ilk dozunu döndür
    if (sortedTimes.isNotEmpty) {
      return {
        'time': sortedTimes.first,
        'isOverdue': false,
        'isTomorrow': true
      };
    }

    return {'time': null};
  }

  /// Geri sayım metnini hesapla
  String _getCountdown(String? nextDose, {bool isTomorrow = false}) {
    if (nextDose == null) return 'Tamamlandı';

    final now = DateTime.now();
    final parts = nextDose.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    DateTime nextTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (isTomorrow) {
      nextTime = nextTime.add(const Duration(days: 1));
    }

    // Eğer zaman geçtiyse gecikme hesapla (Gecikme durumu genellikle "Yarın" ile çelişir ama kontrol edelim)
    if (nextTime.isBefore(now)) {
      final diff = now.difference(nextTime);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      if (hours > 0) return 'Gecikme: $hours sa $minutes dk';
      return 'Gecikme: $minutes dk';
    }

    // Gelecekteyse kalan süreyi hesapla
    final diff = nextTime.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 0) {
      return '$hours sa $minutes dk';
    } else if (minutes > 0) {
      return '$minutes dk';
    } else {
      return 'Şimdi!';
    }
  }

  /// Geri sayıma göre renk
  Color _getCountdownColor(String countdown) {
    if (countdown.contains('Gecikme')) {
      return Colors.red;
    }
    if (countdown.contains('Tamamlandı')) {
      return Colors.green;
    }
    if (countdown.contains('Şimdi')) {
      return Colors.red;
    }
    if (countdown.contains('Yarın')) {
      return Colors.blue[700]!;
    }

    // Dakika sayısını çıkar
    final match = RegExp(r'(\d+)\s*dk').firstMatch(countdown);
    final hourMatch = RegExp(r'(\d+)\s*saat').firstMatch(countdown);

    int totalMinutes = 0;
    if (hourMatch != null) {
      totalMinutes += int.parse(hourMatch.group(1)!) * 60;
    }
    if (match != null) {
      totalMinutes += int.parse(match.group(1)!);
    }

    if (totalMinutes <= 30) {
      return Colors.orange;
    } else if (totalMinutes <= 60) {
      return Colors.amber[700]!;
    } else {
      return Colors.green;
    }
  }

  /// Durum ikonu
  Widget _buildStatusIcon(String countdown) {
    if (countdown.contains('Gecikme')) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.warning_amber_rounded,
            color: Colors.white, size: 20),
      );
    }
    if (countdown.contains('Şimdi')) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.notifications_active,
            color: Colors.white, size: 20),
      );
    }
    if (countdown.contains('Yarın')) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.calendar_today_rounded,
            color: Colors.blue[700], size: 20),
      );
    }
    return const SizedBox.shrink();
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlacı Sil'),
        content: Text(
            '${widget.medicine.name} ilacını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.service.deleteMedicine(widget.medicine.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.medicine.name} silindi')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Silme hatası: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
