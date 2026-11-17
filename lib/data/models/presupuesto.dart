import 'package:flutter/material.dart';

import '../../core/utils/busqueda.dart';
import 'comunes.dart';

enum EstadoPresupuesto {
  pendiente('pendiente', 'Pendiente', Icons.schedule_rounded),
  aprobado('aprobado', 'Aprobado', Icons.thumb_up_alt_outlined),
  rechazado('rechazado', 'Rechazado', Icons.thumb_down_alt_outlined);

  const EstadoPresupuesto(this.valor, this.etiqueta, this.icono);
  final String valor;
  final String etiqueta;
  final IconData icono;

  static EstadoPresupuesto desde(String? v) =>
      values.firstWhere((e) => e.valor == v, orElse: () => pendiente);
}

class Presupuesto {
  const Presupuesto({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono = '',
    this.equipo = '',
    this.items = const [],
    this.notas = '',
    this.estado = EstadoPresupuesto.pendiente,
    this.validezDias = 15,
    required this.fecha,
    this.ordenId,
  });

  final String id;
  final int numero;
  final String clienteId;
  final String clienteNombre;
  final String clienteTelefono;
  final String equipo;
  final List<ItemLinea> items;

  /// Condiciones u observaciones que se imprimen en el PDF.
  final String notas;
  final EstadoPresupuesto estado;
  final int validezDias;
  final DateTime fecha;

  /// Trabajo generado a partir de este presupuesto, si se convirtió.
  final String? ordenId;

  double get total => ItemLinea.total(items);
  DateTime get vence => fecha.add(Duration(days: validezDias));
  bool get vencido => estado == EstadoPresupuesto.pendiente && vence.isBefore(DateTime.now());

  factory Presupuesto.fromMap(String id, Map<String, dynamic> m) => Presupuesto(
        id: id,
        numero: leerInt(m['numero']),
        clienteId: leerTexto(m['clienteId']),
        clienteNombre: leerTexto(m['clienteNombre']),
        clienteTelefono: leerTexto(m['clienteTelefono']),
        equipo: leerTexto(m['equipo']),
        items: ItemLinea.listaDesde(m['items']),
        notas: leerTexto(m['notas']),
        estado: EstadoPresupuesto.desde(m['estado'] as String?),
        validezDias: m['validezDias'] == null ? 15 : leerInt(m['validezDias']),
        fecha: leerFecha(m['fecha']) ?? DateTime.now(),
        ordenId: leerTextoONull(m['ordenId']),
      );

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'clienteTelefono': clienteTelefono,
        'equipo': equipo.trim(),
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'notas': notas.trim(),
        'estado': estado.valor,
        'validezDias': validezDias,
        'fecha': fecha,
        'ordenId': ordenId,
        'keywords': Busqueda.keywords([clienteNombre, equipo, numero.toString()]),
      };

  Presupuesto copyWith({
    int? numero,
    String? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    String? equipo,
    List<ItemLinea>? items,
    String? notas,
    EstadoPresupuesto? estado,
    int? validezDias,
    DateTime? fecha,
    String? ordenId,
  }) =>
      Presupuesto(
        id: id,
        numero: numero ?? this.numero,
        clienteId: clienteId ?? this.clienteId,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        clienteTelefono: clienteTelefono ?? this.clienteTelefono,
        equipo: equipo ?? this.equipo,
        items: items ?? this.items,
        notas: notas ?? this.notas,
        estado: estado ?? this.estado,
        validezDias: validezDias ?? this.validezDias,
        fecha: fecha ?? this.fecha,
        ordenId: ordenId ?? this.ordenId,
      );
}
