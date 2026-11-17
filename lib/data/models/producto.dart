import 'package:flutter/material.dart';

import '../../core/utils/busqueda.dart';
import 'comunes.dart';

enum TipoProducto {
  producto('producto', 'Producto', Icons.inventory_2_outlined),
  servicio('servicio', 'Servicio', Icons.handyman_outlined);

  const TipoProducto(this.valor, this.etiqueta, this.icono);
  final String valor;
  final String etiqueta;
  final IconData icono;

  static TipoProducto desde(String? v) => v == 'servicio' ? servicio : producto;
}

/// Artículo del catálogo: un producto con stock (aceite, filtro, repuesto)
/// o un servicio sin stock (mano de obra, diagnóstico).
class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    this.codigo = '',
    this.categoria = '',
    this.tipo = TipoProducto.producto,
    this.precio = 0,
    this.costo = 0,
    this.stock = 0,
    this.stockMinimo = 0,
  });

  final String id;
  final String nombre;
  final String codigo;
  final String categoria;
  final TipoProducto tipo;
  final double precio;
  final double costo;

  /// Sólo lo modifican los movimientos de stock, nunca el formulario.
  final double stock;
  final double stockMinimo;

  bool get controlaStock => tipo == TipoProducto.producto;
  bool get stockBajo => controlaStock && stock <= stockMinimo;
  bool get sinStock => controlaStock && stock <= 0;

  /// Margen sobre el precio de venta, en %. `null` si no hay costo cargado.
  double? get margen => (costo <= 0 || precio <= 0) ? null : (precio - costo) / precio * 100;

  ItemLinea comoItem() => ItemLinea(
        descripcion: nombre,
        precioUnitario: precio,
        productoId: id,
        costoUnitario: costo > 0 ? costo : null,
      );

  factory Producto.fromMap(String id, Map<String, dynamic> m) => Producto(
        id: id,
        nombre: leerTexto(m['nombre']),
        codigo: leerTexto(m['codigo']),
        categoria: leerTexto(m['categoria']),
        tipo: TipoProducto.desde(m['tipo'] as String?),
        precio: leerDouble(m['precio']),
        costo: leerDouble(m['costo']),
        stock: leerDouble(m['stock']),
        stockMinimo: leerDouble(m['stockMinimo']),
      );

  /// Datos editables desde el formulario. No incluye `stock` a propósito.
  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'nombreOrden': Busqueda.normalizar(nombre.trim()),
        'codigo': codigo.trim().toUpperCase(),
        'categoria': categoria.trim(),
        'tipo': tipo.valor,
        'precio': precio,
        'costo': costo,
        'stockMinimo': stockMinimo,
        'stockBajo': controlaStock && stock <= stockMinimo,
        'keywords': Busqueda.keywords([nombre, codigo, categoria]),
      };

  Producto copyWith({double? stock}) => Producto(
        id: id,
        nombre: nombre,
        codigo: codigo,
        categoria: categoria,
        tipo: tipo,
        precio: precio,
        costo: costo,
        stock: stock ?? this.stock,
        stockMinimo: stockMinimo,
      );
}

enum MotivoStock {
  ingreso('ingreso', 'Ingreso de mercadería', Icons.add_box_outlined),
  ajuste('ajuste', 'Ajuste de inventario', Icons.tune_rounded),
  trabajo('trabajo', 'Usado en trabajo', Icons.build_outlined),
  venta('venta', 'Venta', Icons.shopping_bag_outlined),
  devolucion('devolucion', 'Devolución', Icons.undo_rounded);

  const MotivoStock(this.valor, this.etiqueta, this.icono);
  final String valor;
  final String etiqueta;
  final IconData icono;

  static MotivoStock desde(String? v) => values.firstWhere((e) => e.valor == v, orElse: () => ajuste);
}

/// Registro histórico de cada cambio de stock (auditoría).
class MovimientoStock {
  const MovimientoStock({
    required this.id,
    required this.productoId,
    required this.cantidad,
    required this.motivo,
    required this.fecha,
    this.stockResultante = 0,
    this.referencia = '',
  });

  final String id;
  final String productoId;

  /// Positivo entra, negativo sale.
  final double cantidad;
  final MotivoStock motivo;
  final DateTime fecha;
  final double stockResultante;
  final String referencia;

  factory MovimientoStock.fromMap(String id, Map<String, dynamic> m) => MovimientoStock(
        id: id,
        productoId: leerTexto(m['productoId']),
        cantidad: leerDouble(m['cantidad']),
        motivo: MotivoStock.desde(m['motivo'] as String?),
        fecha: leerFecha(m['fecha']) ?? DateTime.now(),
        stockResultante: leerDouble(m['stockResultante']),
        referencia: leerTexto(m['referencia']),
      );
}

/// Cálculos de stock puros (sin Firestore) para poder testearlos.
abstract final class CalculoStock {
  /// Cantidad usada de cada producto del catálogo en [items].
  static Map<String, double> consumo(Iterable<ItemLinea> items) {
    final r = <String, double>{};
    for (final i in items) {
      final id = i.productoId;
      if (id == null || id.isEmpty) continue;
      r.update(id, (v) => v + i.cantidad, ifAbsent: () => i.cantidad);
    }
    return r;
  }

  /// Cuánto hay que sumar al stock de cada producto al pasar de [antes] a
  /// [despues]. Positivo = vuelve al stock; negativo = se descuenta.
  static Map<String, double> diferencia(Iterable<ItemLinea> antes, Iterable<ItemLinea> despues) {
    final a = consumo(antes);
    final d = consumo(despues);
    final r = <String, double>{};
    for (final id in {...a.keys, ...d.keys}) {
      final delta = redondear((a[id] ?? 0) - (d[id] ?? 0));
      if (delta != 0) r[id] = delta;
    }
    return r;
  }
}
