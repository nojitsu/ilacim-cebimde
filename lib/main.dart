import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/medicine_service.dart';
import 'services/history_service.dart';
import 'home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/alarm_screen.dart';

final NotificationService notificationService = NotificationService();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('tr_TR', null);
  await notificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _configureSelectNotificationSubject();
  }

  void _configureSelectNotificationSubject() {
    notificationService.selectNotificationStream.stream
        .listen((String? payload) async {
      debugPrint('Bildirim seçildi: $payload');
      if (payload != null && payload.isNotEmpty) {
        // Payload formatı: id|name|dose|time|audioPath
        final parts = payload.split('|');
        if (parts.length >= 4) {
          final medId = parts[0];
          final medName = parts[1];
          final dose = parts[2];
          final time = parts[3];
          String? audioPath;

          if (parts.length > 4 && parts[4].isNotEmpty) {
            audioPath = parts[4];
          }

          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AlarmScreen(
                medicineId: medId,
                medicineName: medName,
                dose: dose,
                scheduledTime: time,
                audioPath: audioPath,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    notificationService.selectNotificationStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider(
          // notificationService zaten global, burada servise geçiyoruz
          create: (_) => MedicineService(notificationService),
        ),
        ChangeNotifierProvider(create: (_) => HistoryService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // Key'i buraya veriyoruz
        title: 'İlaç Cebimde',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('tr', 'TR')],
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              return const HomeScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
