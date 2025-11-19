import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final pass = _passController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Por favor, complete todos los campos."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // --- LOGICA DE LOGIN (MODIFICADA) ---
        // 1. Iniciar sesión
        UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );

        // 2. VERIFICACIÓN AUTOMÁTICA (Auto-fix para usuarios viejos)
        if (cred.user != null) {
          final userDoc = FirebaseFirestore.instance.collection('users').doc(cred.user!.uid);
          final snapshot = await userDoc.get();

          if (snapshot.exists) {
            // Si el usuario existe, revisamos si le falta el campo 'isPremium'
            final data = snapshot.data();
            if (data != null && !data.containsKey('isPremium')) {
              // ¡Le falta! Se lo agregamos automáticamente como FREE
              await userDoc.update({'isPremium': false});
            }
          } else {
            // Caso raro: Existe en Auth pero no en la Base de Datos -> Lo creamos
            await userDoc.set({
              'email': email,
              'isPremium': false,
              'fechaRegistro': FieldValue.serverTimestamp(),
              'nombreTaller': '',
              'telefono': '',
              'direccion': '',
            });
          }
        }

      } else {
        // --- LOGICA DE REGISTRO (NUEVOS) ---
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );

        if (userCredential.user != null) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'email': email,
            'isPremium': false, // Nacen Free
            'fechaRegistro': FieldValue.serverTimestamp(),
            'nombreTaller': '',
            'telefono': '',
            'direccion': '',
          });
        }
      }

      // La navegación ocurre automáticamente por el StreamBuilder en main.dart

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Error de autenticación'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_isLogin ? "Iniciar Sesión" : "Registrarse"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 80,
                color: colorScheme.primary.withOpacity(0.8),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Correo electrónico",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                      : Text(_isLogin ? "Ingresar" : "Registrarse"),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin
                      ? "¿No tienes cuenta? Crear una"
                      : "¿Ya tienes cuenta? Inicia sesión",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}