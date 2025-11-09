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
  String? _logoBase64; // solo el Base64 puro
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
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
        _logoBase64 = data['logoBase64']; // solo Base64
      });
    }
  }

  /// Subir logo usando HTML File Picker (Flutter Web)
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos del taller guardados')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar datos: $e')),
      );
    } finally {
      setState(() => _cargando = false);
    }
  }

  /// Encabezado horizontal moderno con logo a la izquierda
  Widget _buildHeader(Uint8List? logoBytes) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade700],
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
          // Logo
          GestureDetector(
            onTap: _subirLogo,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                image: logoBytes != null
                    ? DecorationImage(
                  image: MemoryImage(logoBytes),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: logoBytes == null
                  ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          // Datos del taller
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreController.text.isNotEmpty
                      ? _nombreController.text
                      : 'Nombre del Taller',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _telefonoController.text.isNotEmpty
                      ? _telefonoController.text
                      : 'Teléfono',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _direccionController.text.isNotEmpty
                      ? _direccionController.text
                      : 'Dirección',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _emailController.text.isNotEmpty
                      ? _emailController.text
                      : 'Correo electrónico',
                  style: const TextStyle(color: Colors.white70),
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
    Uint8List? logoBytes = _logoBase64 != null
        ? base64Decode(_logoBase64!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Taller'),
        backgroundColor: Colors.indigo,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildHeader(logoBytes), // encabezado moderno
              _buildTextField(_nombreController, 'Nombre del Taller'),
              const SizedBox(height: 10),
              _buildTextField(_direccionController, 'Dirección'),
              const SizedBox(height: 10),
              _buildTextField(_telefonoController, 'Teléfono'),
              const SizedBox(height: 10),
              _buildTextField(
                _emailController,
                'Correo electrónico',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _guardarDatos,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
