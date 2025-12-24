import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/medicine_model.dart';
import '../services/medicine_service.dart';

class AddMedicineScreen extends StatefulWidget {
  final IlacModel? medicine;
  const AddMedicineScreen({super.key, this.medicine});
  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _doseController;
  late TextEditingController _quantityController;
  List<TimeOfDay> _selectedTimes = [];
  bool _hasLimitedQuantity = false;
  String? _selectedAudioPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicine?.name ?? '');
    _doseController = TextEditingController(text: widget.medicine?.dose ?? '');

    // Stok sayısı
    if (widget.medicine != null && widget.medicine!.totalQuantity > 0) {
      _hasLimitedQuantity = true;
      _quantityController = TextEditingController(
        text: widget.medicine!.remainingQuantity.toString(),
      );
    } else {
      _quantityController = TextEditingController(text: '30');
    }

    // Mevcut saatleri yükle
    if (widget.medicine != null && widget.medicine!.times.isNotEmpty) {
      _selectedTimes = widget.medicine!.times.map((timeStr) {
        final parts = timeStr.split(':');
        return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }).toList();
      _selectedAudioPath = widget.medicine!.audioPath;
    } else {
      // Varsayılan olarak bir saat ekle
      _selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  /// Saatleri String listesine çevir
  List<String> _timesToStringList() {
    return _selectedTimes.map((time) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }).toList();
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir kullanım saati ekleyin')),
      );
      return;
    }

    final int quantity =
        _hasLimitedQuantity ? (int.tryParse(_quantityController.text) ?? 0) : 0;

    final service = Provider.of<MedicineService>(context, listen: false);
    final newMedicine = IlacModel(
      id: widget.medicine?.id ?? '',
      name: _nameController.text.trim(),
      dose: _doseController.text.trim(),
      times: _timesToStringList(),
      totalQuantity: quantity,
      remainingQuantity: quantity,
      createdAt: widget.medicine?.createdAt,
      audioPath: _selectedAudioPath,
    );

    try {
      if (widget.medicine != null) {
        // Düzenleme - mevcut kalan miktarı koru
        final updatedMedicine = newMedicine.copyWith(
          remainingQuantity: _hasLimitedQuantity
              ? (int.tryParse(_quantityController.text) ??
                  widget.medicine!.remainingQuantity)
              : 0,
        );
        await service.updateMedicine(updatedMedicine);
      } else {
        await service.addMedicine(newMedicine);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  /// Yeni saat ekle
  Future<void> _addTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) {
        return child!;
      },
    );

    if (picked != null) {
      final exists = _selectedTimes.any(
        (t) => t.hour == picked.hour && t.minute == picked.minute,
      );

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu saat zaten eklenmiş')),
          );
        }
        return;
      }

      setState(() {
        _selectedTimes.add(picked);
        _selectedTimes.sort((a, b) {
          if (a.hour != b.hour) return a.hour.compareTo(b.hour);
          return a.minute.compareTo(b.minute);
        });
      });
    }
  }

  /// Saati düzenle
  Future<void> _editTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
      builder: (context, child) {
        return child!;
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
        _selectedTimes.sort((a, b) {
          if (a.hour != b.hour) return a.hour.compareTo(b.hour);
          return a.minute.compareTo(b.minute);
        });
      });
    }
  }

  /// Saati sil
  void _removeTime(int index) {
    if (_selectedTimes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir saat olmalı')),
      );
      return;
    }

    setState(() {
      _selectedTimes.removeAt(index);
    });
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.medicine != null ? 'İlacı Düzenle' : 'Yeni İlaç Ekle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // İlaç Adı
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'İlaç Adı',
                  prefixIcon: Icon(Icons.medication),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'İlaç adı gerekli' : null,
              ),
              const SizedBox(height: 16),

              // Doz
              TextFormField(
                controller: _doseController,
                decoration: const InputDecoration(
                  labelText: 'Doz (Örn: 500mg, 1 tablet)',
                  prefixIcon: Icon(Icons.science),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Doz bilgisi gerekli' : null,
              ),
              const SizedBox(height: 24),

              // Stok Sayısı
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Colors.orange),
                          const SizedBox(width: 8),
                          const Text(
                            'İlaç Stok Takibi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _hasLimitedQuantity,
                            onChanged: (value) {
                              setState(() => _hasLimitedQuantity = value);
                            },
                          ),
                        ],
                      ),
                      if (_hasLimitedQuantity) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Kalan Adet',
                            prefixIcon: Icon(Icons.numbers),
                            border: OutlineInputBorder(),
                            helperText: 'Kutudaki toplam ilaç sayısı',
                          ),
                          validator: (v) {
                            if (!_hasLimitedQuantity) return null;
                            if (v == null || v.isEmpty) return 'Adet gerekli';
                            final num = int.tryParse(v);
                            if (num == null || num <= 0)
                              return 'Geçerli bir sayı girin';
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Kullanım Saatleri Başlık
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kullanım Saatleri (${_selectedTimes.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addTime,
                    icon: const Icon(Icons.add_alarm, size: 18),
                    label: const Text('Saat Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Saat Listesi
              if (_selectedTimes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Henüz saat eklenmedi. "Saat Ekle" butonuna tıklayın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...List.generate(_selectedTimes.length, (index) {
                  final time = _selectedTimes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        _formatTime(time),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(_getTimeLabel(time)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editTime(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeTime(index),
                          ),
                        ],
                      ),
                      onTap: () => _editTime(index),
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // Alarm Sesi Seçimi
              Card(
                child: ListTile(
                  leading: const Icon(Icons.music_note, color: Colors.purple),
                  title: const Text('Alarm Sesi'),
                  subtitle: Text(_selectedAudioPath != null
                      ? path.basename(_selectedAudioPath!)
                      : 'Uygulama Varsayılanı'),
                  trailing: TextButton(
                    onPressed: _pickAudioFile,
                    child: const Text('Değiştir'),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Kaydet Butonu
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveMedicine,
                  icon: const Icon(Icons.save),
                  label: const Text('Kaydet', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Saat için açıklayıcı etiket
  String _getTimeLabel(TimeOfDay time) {
    if (time.hour >= 5 && time.hour < 12) {
      return 'Sabah';
    } else if (time.hour >= 12 && time.hour < 17) {
      return 'Öğle';
    } else if (time.hour >= 17 && time.hour < 21) {
      return 'Akşam';
    } else {
      return 'Gece';
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        // Kalıcı depolamaya kopyala
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(result.files.single.path!);
        final savedImage = await File(result.files.single.path!)
            .copy('${appDir.path}/$fileName');

        setState(() {
          _selectedAudioPath = savedImage.path;
        });
      }
    } catch (e) {
      debugPrint('Dosya seçme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ses dosyası seçilemedi')),
        );
      }
    }
  }
}
