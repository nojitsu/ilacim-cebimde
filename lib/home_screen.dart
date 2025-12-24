import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'screens/medicine_list_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/add_medicine_screen.dart';
import 'screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    MedicineListScreen(),
    CalendarScreen(),
    // ProfileScreen included below as a separate widget
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildPage() {
    if (_selectedIndex < _pages.length) return _pages[_selectedIndex];
    // index 2 -> profile
    return const ProfileScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İlaç Cebimde'),
        actions: [
          if (_selectedIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
                ),
                icon: const Icon(Icons.add_circle, color: Colors.white),
                label: const Text(
                  'İlaç Ekle',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _buildPage(),
      // floatingActionButton kaldırıldı
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'İlaçlarım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Takvim',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _photoUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotoUrl();
  }

  Future<void> _loadPhotoUrl() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _photoUrl = doc.data()?['photoUrl'];
        });
      }
    } catch (e) {
      debugPrint('Fotoğraf yüklenemedi: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _loading = true);

      // Fotoğrafı base64 olarak kaydet (basit yöntem)
      final bytes = await image.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'photoUrl': base64Image}, SetOptions(merge: true));

        if (mounted) {
          setState(() {
            _photoUrl = base64Image;
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil fotoğrafı güncellendi!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profil Fotoğrafı
            Stack(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.blue, width: 3),
                      image: _photoUrl != null
                          ? DecorationImage(
                              image: _photoUrl!.startsWith('data:')
                                  ? MemoryImage(
                                      base64Decode(_photoUrl!.split(',')[1]))
                                  : NetworkImage(_photoUrl!) as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _photoUrl == null
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Email
            Card(
              child: ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: const Text('E-posta'),
                subtitle: Text(user?.email ?? 'Bilinmiyor'),
              ),
            ),
            const SizedBox(height: 8),

            // Kayıt Tarihi
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.green),
                title: const Text('Kayıt Tarihi'),
                subtitle: Text(
                  user?.metadata.creationTime != null
                      ? '${user!.metadata.creationTime!.day}/${user.metadata.creationTime!.month}/${user.metadata.creationTime!.year}'
                      : 'Bilinmiyor',
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Çıkış Yap Butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış Yap', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
