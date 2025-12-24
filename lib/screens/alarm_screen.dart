import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/medicine_model.dart';
import '../services/medicine_service.dart';

class AlarmScreen extends StatefulWidget {
  final String medicineId;
  final String medicineName;
  final String dose;
  final String scheduledTime;
  final String? audioPath;

  const AlarmScreen({
    super.key,
    required this.medicineId,
    required this.medicineName,
    required this.dose,
    required this.scheduledTime,
    this.audioPath,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playAlarm();
  }

  Future<void> _playAlarm() async {
    try {
      if (widget.audioPath != null && widget.audioPath!.isNotEmpty) {
        final file = File(widget.audioPath!);
        if (await file.exists()) {
          // Özel ses çal
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(DeviceFileSource(widget.audioPath!));
        } else {
          // Dosya bulunamazsa varsayılan
          _playDefaultAlarm();
        }
      } else {
        // Varsayılan ses
        _playDefaultAlarm();
      }
    } catch (e) {
      debugPrint('Ses çalma hatası: $e');
    }
  }

  Future<void> _playDefaultAlarm() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/alarm_sound.mp3'));
    } catch (e) {
      debugPrint('Varsayılan ses hatası: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Alarm İkonu Animasyonu
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 1.0, end: 1.2),
              duration: const Duration(seconds: 1),
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              onEnd: () {
                // Tekrar eden animasyon eklenebilir
              },
              child: const Icon(
                Icons.alarm,
                size: 100,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              'İlaç Vakti!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // İlaç Bilgileri
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    widget.medicineName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.dose,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.scheduledTime,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Aksiyon Butonları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                children: [
                  // İlacı Aldım (Büyük Buton)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () => _takeMedicine(context),
                      icon: const Icon(Icons.check, size: 30),
                      label: const Text(
                        'İlacı Aldım',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Ertele
                      TextButton.icon(
                        onPressed: () => _snooze(context),
                        icon: const Icon(Icons.snooze, color: Colors.white70),
                        label: const Text(
                          '5 dk Ertele',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),

                      // Kapat (X)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                        label: const Text(
                          'Kapat',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takeMedicine(BuildContext context) async {
    final service = Provider.of<MedicineService>(context, listen: false);

    // Stop audio
    await _audioPlayer.stop();

    // Model nesnesini oluşturmak için geçici veri
    final tempMed = IlacModel(
      id: widget.medicineId,
      name: widget.medicineName,
      dose: widget.dose,
      times: [], // Önemsiz
    ); // Diğer alanlar varsayılan

    // İlaç alma işlemi
    await service.takeMedicine(
      tempMed,
      scheduledTime: widget.scheduledTime,
    );

    if (context.mounted) {
      Navigator.of(context).pop(); // Ekranı kapat
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harika! İlaç alındı olarak kaydedildi.')),
      );
    }
  }

  void _snooze(BuildContext context) {
    _audioPlayer.stop();
    Navigator.of(context).pop();
  }
}
