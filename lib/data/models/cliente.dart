import '../../core/utils/busqueda.dart';
import 'comunes.dart';
import 'fiscal.dart';

class Cliente {
  const Cliente({
    required this.id,
    required this.nombre,
    this.telefono = '',
    this.email = '',
    this.documento = '',
    this.direccion = '',
    this.notas = '',
    this.fechaAlta,
    this.condicionIva = CondicionIva.consumidorFinal,
  });

  final String id;
  final String nombre;
  final String telefono;
  final String email;

  /// DNI o CUIT.
  final String documento;
  final String direccion;
  final String notas;
  final DateTime? fechaAlta;

  /// Para facturar: define si corresponde factura A o B.
  final CondicionIva condicionIva;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  factory Cliente.fromMap(String id, Map<String, dynamic> m) => Cliente(
        id: id,
        nombre: leerTexto(m['nombre']),
        telefono: leerTexto(m['telefono'] ?? m['numero']),
        email: leerTexto(m['email']),
        documento: leerTexto(m['documento']),
        direccion: leerTexto(m['direccion']),
        notas: leerTexto(m['notas']),
        fechaAlta: leerFecha(m['fechaAlta'] ?? m['fechaRegistro']),
        condicionIva: CondicionIva.desde(m['condicionIva'] as String?),
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'nombreOrden': Busqueda.normalizar(nombre.trim()),
        'telefono': telefono.trim(),
        'email': email.trim(),
        'documento': documento.trim(),
        'direccion': direccion.trim(),
        'notas': notas.trim(),
        'condicionIva': condicionIva.valor,
        'keywords': Busqueda.keywords([nombre, telefono, documento, email.split('@').first]),
      };
}
