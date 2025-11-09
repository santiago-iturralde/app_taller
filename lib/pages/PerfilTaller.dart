import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PerfilTallerScreen extends StatefulWidget {
  final String uid;
  const PerfilTallerScreen({super.key, required this.uid});

  @override
  State<PerfilTallerScreen> createState() => _PerfilTallerScreenState();
}

class _PerfilTallerScreenState extends State<PerfilTallerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  String? _logoBase64;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        _nombreController.text = data['nombreTaller'] ?? '';
        _direccionController.text = data['direccion'] ?? '';
        _telefonoController.text = data['telefono'] ?? '';
        _emailController.text = data['email'] ?? '';
        setState(() {
          _logoBase64 = data['logoBase64'];
        });
      }
    } catch (e) {
      // Manejar error si es necesario
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _subirLogo() async {
    try {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();

      input.onChange.listen((event) async {
        final file = input.files?.first;
        if (file == null) return;

        setState(() => _cargando = true);

        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((event) async {
          final dataUrl = reader.result as String;
          final base64String = dataUrl.split(',').last;

          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .set({'logoBase64': base64String}, SetOptions(merge: true));

          setState(() {
            _logoBase64 = base64String;
            _cargando = false;
          });
        });
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir logo: $e')),
        );
      }
    }
  }

  Future<void> _guardarDatos() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'nombreTaller': _nombreController.text,
        'direccion': _direccionController.text,
        'telefono': _telefonoController.text,
        'email': _emailController.text,
        'logoBase64': _logoBase64,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos del taller guardados')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al guardar datos: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Widget _buildHeader(Uint8List? logoBytes, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.8),
            colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _subirLogo,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.onPrimary.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                image: logoBytes != null
                    ? DecorationImage(
                  image: MemoryImage(logoBytes),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: logoBytes == null
                  ? Icon(Icons.add_a_photo,
                  size: 40, color: colorScheme.primary)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreController.text.isNotEmpty
                      ? _nombreController.text
                      : 'Nombre del Taller',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _telefonoController.text.isNotEmpty
                      ? _telefonoController.text
                      : 'Teléfono',
                  style:
                  TextStyle(color: colorScheme.onPrimary.withOpacity(0.8)),
                ),
                const SizedBox(height: 4),
                Text(
                  _direccionController.text.isNotEmpty
                      ? _direccionController.text
                      : 'Dirección',
                  style:
                  TextStyle(color: colorScheme.onPrimary.withOpacity(0.8)),
                ),
                const SizedBox(height: 4),
                Text(
                  _emailController.text.isNotEmpty
                      ? _emailController.text
                      : 'Correo electrónico',
                  style:
                  TextStyle(color: colorScheme.onPrimary.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Uint8List? logoBytes =
    _logoBase64 != null ? base64Decode(_logoBase64!) : null;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Taller'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildHeader(logoBytes, colorScheme),

              TextFormField(
                controller: _nombreController,
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Taller',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _direccionController,
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telefonoController,
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _guardarDatos,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}