import 'package:flutter/material.dart';

import 'comunes.dart';

enum MedioPago {
  efectivo('efectivo', 'Efectivo', Icons.payments_outlined),
  transferencia('transferencia', 'Transferencia', Icons.account_balance_outlined),
  mercadoPago('mercado_pago', 'Mercado Pago', Icons.qr_code_2_rounded),
  debito('debito', 'Tarjeta de débito', Icons.credit_card_outlined),
  credito('credito', 'Tarjeta de crédito', Icons.credit_card_rounded),
  otro('otro', 'Otro', Icons.more_horiz_rounded);

  const MedioPago(this.valor, this.etiqueta, this.icono);
  final String valor;
  final String etiqueta;
  final IconData icono;

  static MedioPago desde(String? v) => values.firstWhere((e) => e.valor == v, orElse: () => otro);
}

/// Un cobro (ingreso de dinero). Cada cobro tiene número de recibo
/// correlativo. No se borran: se anulan, para no dejar huecos en la
/// numeración.
class Pago {
  const Pago({
    required this.id,
    required this.numero,
    required this.monto,
    required this.fecha,
    this.medio = MedioPago.efectivo,
    this.concepto = '',
    this.clienteId,
    this.clienteNombre = '',
    this.ordenId,
    this.ordenNumero,
    this.anulado = false,
    this.excluirDeCaja = false,
    this.items = const [],
  });

  final String id;
  final int numero;
  final double monto;
  final DateTime fecha;
  final MedioPago medio;
  final String concepto;
  final String? clienteId;
  final String clienteNombre;
  final String? ordenId;
  final int? ordenNumero;
  final bool anulado;

  /// Comprobantes importados del sistema anterior que no se contaban
  /// como ingreso (para no duplicar lo cobrado en reparaciones).
  final bool excluirDeCaja;

  /// Detalle de lo vendido (sólo en ventas de mostrador).
  final List<ItemLinea> items;

  bool get cuentaEnCaja => !anulado && !excluirDeCaja;
  bool get esVenta => items.isNotEmpty;

  factory Pago.fromMap(String id, Map<String, dynamic> m) => Pago(
        id: id,
        numero: leerInt(m['numero']),
        monto: leerDouble(m['monto']),
        fecha: leerFecha(m['fecha']) ?? DateTime.now(),
        medio: MedioPago.desde(m['medio'] as String?),
        concepto: leerTexto(m['concepto']),
        clienteId: leerTextoONull(m['clienteId']),
        clienteNombre: leerTexto(m['clienteNombre']),
        ordenId: leerTextoONull(m['ordenId']),
        ordenNumero: m['ordenNumero'] == null ? null : leerInt(m['ordenNumero']),
        anulado: m['anulado'] == true,
        excluirDeCaja: m['excluirDeCaja'] == true,
        items: ItemLinea.listaDesde(m['items']),
      );

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'monto': monto,
        'fecha': fecha,
        'medio': medio.valor,
        'concepto': concepto.trim(),
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'ordenId': ordenId,
        'ordenNumero': ordenNumero,
        'anulado': anulado,
        'excluirDeCaja': excluirDeCaja,
        if (items.isNotEmpty) 'items': items.map((i) => i.toMap()).toList(),
      };
}

class Gasto {
  const Gasto({
    required this.id,
    required this.descripcion,
    required this.monto,
    required this.categoria,
    required this.fecha,
    this.medio = MedioPago.efectivo,
  });

  final String id;
  final String descripcion;
  final double monto;
  final String categoria;
  final DateTime fecha;
  final MedioPago medio;

  factory Gasto.fromMap(String id, Map<String, dynamic> m) => Gasto(
        id: id,
        descripcion: leerTexto(m['descripcion']),
        monto: leerDouble(m['monto']),
        categoria: leerTexto(m['categoria']).isEmpty ? 'Otros' : leerTexto(m['categoria']),
        fecha: leerFecha(m['fecha']) ?? DateTime.now(),
        medio: MedioPago.desde(m['medio'] as String?),
      );

  Map<String, dynamic> toMap() => {
        'descripcion': descripcion.trim(),
        'monto': monto,
        'categoria': categoria,
        'fecha': fecha,
        'medio': medio.valor,
      };
}
