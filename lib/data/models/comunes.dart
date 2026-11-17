import 'package:cloud_firestore/cloud_firestore.dart';

/// Conversores tolerantes para leer documentos de Firestore sin romper si
/// falta un campo o viene con otro tipo (datos viejos o cargados a mano).
DateTime? leerFecha(Object? valor) => switch (valor) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      _ => null,
    };

double leerDouble(Object? valor) => switch (valor) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

int leerInt(Object? valor) => switch (valor) {
      num n => n.toInt(),
      String s => int.tryParse(s) ?? 0,
      _ => 0,
    };

String leerTexto(Object? valor) => valor?.toString() ?? '';

String? leerTextoONull(Object? valor) {
  final t = valor?.toString().trim();
  return (t == null || t.isEmpty) ? null : t;
}

List<String> leerListaTexto(Object? valor) =>
    valor is List ? valor.map((e) => e.toString()).toList() : const [];

double redondear(double valor) => (valor * 100).round() / 100;

/// Una línea de detalle (mano de obra, repuesto, servicio…).
class ItemLinea {
  const ItemLinea({required this.descripcion, this.cantidad = 1, this.precioUnitario = 0});

  final String descripcion;
  final double cantidad;
  final double precioUnitario;

  double get subtotal => redondear(cantidad * precioUnitario);

  ItemLinea copyWith({String? descripcion, double? cantidad, double? precioUnitario}) => ItemLinea(
        descripcion: descripcion ?? this.descripcion,
        cantidad: cantidad ?? this.cantidad,
        precioUnitario: precioUnitario ?? this.precioUnitario,
      );

  factory ItemLinea.fromMap(Map<String, dynamic> m) => ItemLinea(
        descripcion: leerTexto(m['descripcion'] ?? m['desc']),
        cantidad: m['cantidad'] == null ? 1 : leerDouble(m['cantidad']),
        precioUnitario: leerDouble(m['precioUnitario'] ?? m['precio']),
      );

  Map<String, dynamic> toMap() => {
        'descripcion': descripcion,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
      };

  static List<ItemLinea> listaDesde(Object? valor) => valor is List
      ? valor.whereType<Map>().map((m) => ItemLinea.fromMap(Map<String, dynamic>.from(m))).toList()
      : const [];

  static double total(Iterable<ItemLinea> items) => redondear(items.fold(0.0, (s, i) => s + i.subtotal));
}
