import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme.dart'; // Importamos tu tema premium

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

    // Agregamos listeners para que la tarjeta superior se actualice en vivo mientras escribís
    _nombreController.addListener(() => setState(() {}));
    _direccionController.addListener(() => setState(() {}));
    _telefonoController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
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
        const SnackBar(
          content: Text('✅ Datos del taller guardados con éxito'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al guardar datos: $e'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Widget _buildHeader(Uint8List? logoBytes) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Área del Logo
          GestureDetector(
            onTap: _subirLogo,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                    ],
                    image: logoBytes != null
                        ? DecorationImage(
                      image: MemoryImage(logoBytes),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: logoBytes == null
                      ? const Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey)
                      : null,
                ),
                // Iconito flotante de edición
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)
                      ]
                  ),
                  child: const Icon(Icons.camera_alt, size: 14, color: AppTheme.primaryBlue),
                )
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Área de Información
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreController.text.isNotEmpty
                      ? _nombreController.text
                      : 'Nombre del Taller',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (_telefonoController.text.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_telefonoController.text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (_direccionController.text.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_direccionController.text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (_emailController.text.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.email, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_emailController.text, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    ],
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
    Uint8List? logoBytes = _logoBase64 != null ? base64Decode(_logoBase64!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Taller'),
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(logoBytes),

              const Text("Datos de Configuración", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nombreController,
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Taller',
                  prefixIcon: Icon(Icons.store_mall_directory_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccionController,
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                decoration: const InputDecoration(
                  labelText: 'Dirección Comercial',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                decoration: const InputDecoration(
                  labelText: 'Teléfono de Contacto',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _guardarDatos,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}