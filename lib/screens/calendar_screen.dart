import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/medicine_model.dart';
import '../models/medicine_intake_model.dart';
import '../services/medicine_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final medicineService =
        Provider.of<MedicineService>(context, listen: false);

    // 1. Stream: Tüm ilaçları getir
    return StreamBuilder<List<IlacModel>>(
      stream: medicineService.getMedicines(),
      builder: (context, medSnapshot) {
        final medicines = medSnapshot.data ?? [];

        // 2. Stream: Seçili günün kayıtlarını getir
        return StreamBuilder<List<MedicineIntakeModel>>(
          stream: medicineService.getIntakesForDay(_selectedDay),
          builder: (context, intakeSnapshot) {
            final intakes = intakeSnapshot.data ?? [];

            return Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  locale: 'tr_TR',
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.deepOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      // Bu kısım performans için basitleştirilebilir
                      // Şimdilik ana listeden hesaplama yapmıyoruz çünkü her gün için ayrı stream gerekir
                      // İleride buraya da bir çözüm düşünülebilir
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 8.0),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDay),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Durum Özeti (İstatistik)
                _buildDailyStats(medicines, intakes),

                // İlaç Programı
                Expanded(
                  child: _buildDaySchedule(medicines, intakes),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDailyStats(
      List<IlacModel> medicines, List<MedicineIntakeModel> intakes) {
    int total = 0;
    int taken = 0;
    int missed = 0;

    // Basit bir hesaplama
    final validDoses = _calculateDoses(medicines, intakes);
    total = validDoses.length;

    for (var dose in validDoses) {
      if (dose['status'] == 'taken') taken++;
      if (dose['status'] == 'missed') missed++;
    }

    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Toplam', total.toString(), Colors.blue),
          _buildStatItem('Alınan', taken.toString(), Colors.green),
          _buildStatItem('Atlanan', missed.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  /// Tüm ilaçları ve durumlarını hesapla
  List<Map<String, dynamic>> _calculateDoses(
      List<IlacModel> medicines, List<MedicineIntakeModel> intakes) {
    List<Map<String, dynamic>> allDoses = [];
    final now = DateTime.now();
    final isToday = isSameDay(_selectedDay, now);

    // Sadece tarih (saatsiz)
    final selectedDateOnly =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

    for (final med in medicines) {
      // 1. Tarih Kontrolü: İlaç bu tarihte var mıydı?
      final createdDateOnly =
          DateTime(med.createdAt.year, med.createdAt.month, med.createdAt.day);
      if (selectedDateOnly.isBefore(createdDateOnly)) {
        continue; // İlaç henüz eklenmemiş
      }

      for (final time in med.times) {
        // Bu saat için intake kaydı var mı?
        final intake = intakes.firstWhere(
            (i) => i.medicineId == med.id && i.scheduledTime == time,
            orElse: () => MedicineIntakeModel(
                  id: 'temp',
                  medicineId: '',
                  medicineName: '',
                  dose: '',
                  scheduledTime: '',
                  scheduledDate: now,
                  status: 'unknown',
                )); // Boş model

        String status = 'pending';

        if (intake.status != 'unknown') {
          status = intake.status; // taken, snoozed vs.
        } else {
          // Kayıt yok, durumu biz belirleyelim
          if (selectedDateOnly
              .isBefore(DateTime(now.year, now.month, now.day))) {
            // Geçmiş bir gün -> Alınmadı
            status = 'missed';
          } else if (isToday) {
            // Bugün -> Saati geçti mi?
            final parts = time.split(':');
            final scheduledHour = int.tryParse(parts[0]) ?? 0;
            final scheduledMinute = int.tryParse(parts[1]) ?? 0;

            final scheduledDateTime = DateTime(
                now.year, now.month, now.day, scheduledHour, scheduledMinute);

            if (now.isAfter(scheduledDateTime)) {
              status = 'missed'; // Saati geçmiş
            } else {
              status = 'pending'; // Henüz saati gelmemiş
            }
          } else {
            // Gelecek bir gün
            status = 'pending';
          }
        }

        allDoses.add({
          'medicine': med,
          'time': time,
          'status': status,
          'intake': intake.status != 'unknown' ? intake : null,
        });
      }
    }

    // Saate göre sırala
    allDoses
        .sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));
    return allDoses;
  }

  Widget _buildDaySchedule(
      List<IlacModel> medicines, List<MedicineIntakeModel> intakes) {
    final allDoses = _calculateDoses(medicines, intakes);

    if (allDoses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Bu tarihte ilaç kaydı yok',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: allDoses.length,
      itemBuilder: (context, index) {
        final dose = allDoses[index];
        final med = dose['medicine'] as IlacModel;
        final time = dose['time'] as String;
        final status = dose['status'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: status == 'pending' ? 2 : 0,
          color: status == 'taken'
              ? Colors.green[50]
              : (status == 'missed' ? Colors.red[50] : Colors.white),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(status),
              child:
                  Icon(_getStatusIcon(status), color: Colors.white, size: 20),
            ),
            title: Text(
              med.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration:
                    status == 'taken' ? TextDecoration.lineThrough : null,
                color: status == 'missed' ? Colors.red[900] : Colors.black87,
              ),
            ),
            subtitle: Text('${med.dose} • $time'),
            trailing:
                _buildActionButtons(context, med, time, status, _selectedDay),
          ),
        );
      },
    );
  }

  Widget? _buildActionButtons(BuildContext context, IlacModel med, String time,
      String status, DateTime date) {
    // Sadece bugün ve geçmiş için aksiyon butonları gösterilebilir, ya da sadece "bugün" için mi?
    // Kullanıcı geçmişi düzeltebilsin mi? Evet, mantıklı olabilir.
    // Gelecekteki ilaçlar için işlem yapılamaz.

    final now = DateTime.now();
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));

    if (isFuture) return null; // Gelecekte işlem yok

    if (status == 'taken') {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    // Alınmadı veya Bekliyor ise "Aldım" butonu göster
    return ElevatedButton(
      onPressed: () => _manualTakeMedicine(context, med, time, date),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(60, 30),
      ),
      child: const Text('Aldım'),
    );
  }

  Future<void> _manualTakeMedicine(
      BuildContext context, IlacModel med, String time, DateTime date) async {
    final service = Provider.of<MedicineService>(context, listen: false);

    // Geçmiş bir gün için mi alınıyor?
    // takeMedicine metodu stok düşüyor ve intake oluşturuyor.
    // Eğer geçmiş bir günse sadece kayıt oluşturup stok düşmeli mi? Evet, stok her zaman düşmeli.

    try {
      await service.takeMedicine(
        med,
        scheduledTime: time,
        scheduledDate: date,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İlaç alındı olarak işaretlendi')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'taken':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'snoozed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'taken':
        return Icons.check;
      case 'missed':
        return Icons.close;
      case 'snoozed':
        return Icons.snooze;
      default:
        return Icons.schedule;
    }
  }
}
