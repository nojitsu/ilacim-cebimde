import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _errorMessage = '';
  bool _isLoading = false;

  Future<void> _submit(bool isLogin) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message ?? 'Hata oluştu.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş / Kayıt')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Email giriniz' : null,
                onSaved: (v) => _email = v!.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Şifre'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'En az 6 karakter' : null,
                onSaved: (v) => _password = v!.trim(),
              ),
              const SizedBox(height: 10),
              if (_errorMessage.isNotEmpty)
                Text(_errorMessage, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => _submit(true),
                      child: const Text('Giriş Yap'),
                    ),
                    TextButton(
                      onPressed: () => _submit(false),
                      child: const Text('Kayıt Ol'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
