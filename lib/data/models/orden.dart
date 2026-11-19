import 'package:flutter/material.dart';

import '../../core/utils/busqueda.dart';
import 'comunes.dart';

/// Ciclo de vida de un trabajo. El orden de declaración es el orden
/// natural del flujo y se usa para sugerir el "siguiente paso".
enum EstadoOrden {
  recibido('recibido', 'Recibido', Icons.inventory_2_outlined),
  enProceso('en_proceso', 'En proceso', Icons.build_outlined),
  esperandoRepuesto('esperando_repuesto', 'Esperando repuesto', Icons.hourglass_top_rounded),
  listo('listo', 'Listo para retirar', Icons.check_circle_outline_rounded),
  entregado('entregado', 'Entregado', Icons.task_alt_rounded),
  cancelado('cancelado', 'Cancelado', Icons.block_rounded);

  const EstadoOrden(this.valor, this.etiqueta, this.icono);

  final String valor;
  final String etiqueta;
  final IconData icono;

  bool get activo => this != entregado && this != cancelado;

  static EstadoOrden desde(String? v) =>
      EstadoOrden.values.firstWhere((e) => e.valor == v, orElse: () => recibido);

  /// Siguiente estado sugerido como acción principal.
  EstadoOrden? get siguiente => switch (this) {
        recibido => enProceso,
        enProceso => listo,
        esperandoRepuesto => enProceso,
        listo => entregado,
        entregado || cancelado => null,
      };

  static const activos = [recibido, enProceso, esperandoRepuesto, listo];
}

class Equipo {
  const Equipo({this.descripcion = '', this.identificador = '', this.kilometraje});

  final String descripcion;
  final String identificador;
  final int? kilometraje;

  factory Equipo.fromMap(Map<String, dynamic>? m) => m == null
      ? const Equipo()
      : Equipo(
          descripcion: leerTexto(m['descripcion']),
          identificador: leerTexto(m['identificador']),
          kilometraje: m['kilometraje'] == null ? null : leerInt(m['kilometraje']),
        );

  Map<String, dynamic> toMap() => {
        'descripcion': descripcion.trim(),
        'identificador': identificador.trim().toUpperCase(),
        if (kilometraje != null) 'kilometraje': kilometraje,
      };
}

/// Orden de trabajo: lo que el cliente trae, qué se le hace y cuánto paga.
class Orden {
  const Orden({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono = '',
    this.equipo = const Equipo(),
    this.problema = '',
    this.notas = '',
    this.estado = EstadoOrden.recibido,
    this.items = const [],
    this.pagado = 0,
    required this.fechaIngreso,
    this.fechaListo,
    this.fechaEntrega,
    this.fechaEstimada,
    this.proximoServiceFecha,
    this.proximoServiceKm,
    this.recordatorioEnviado = false,
    this.facturaId,
  });

  final String id;
  final int numero;
  final String clienteId;
  final String clienteNombre;
  final String clienteTelefono;
  final Equipo equipo;
  final String problema;

  /// Notas internas (diagnóstico, observaciones). No se imprimen.
  final String notas;
  final EstadoOrden estado;
  final List<ItemLinea> items;
  final double pagado;
  final DateTime fechaIngreso;
  final DateTime? fechaListo;
  final DateTime? fechaEntrega;
  final DateTime? fechaEstimada;

  /// Próximo service o mantenimiento sugerido (para recordarle al cliente).
  final DateTime? proximoServiceFecha;
  final int? proximoServiceKm;
  final bool recordatorioEnviado;

  /// Factura electrónica emitida (la asigna el servidor).
  final String? facturaId;

  bool get tieneProximoService => proximoServiceFecha != null || proximoServiceKm != null;

  /// Ítems que efectivamente consumen stock (un trabajo cancelado no consume).
  List<ItemLinea> get itemsQueConsumenStock => estado == EstadoOrden.cancelado ? const [] : items;

  double get total => ItemLinea.total(items);
  double get saldo => redondear((total - pagado).clamp(0, double.infinity).toDouble());
  bool get sinPresupuestar => items.isEmpty || total == 0;
  bool get pagadoCompleto => !sinPresupuestar && saldo <= 0;
  bool get atrasada =>
      estado.activo && fechaEstimada != null && fechaEstimada!.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  factory Orden.fromMap(String id, Map<String, dynamic> m) => Orden(
        id: id,
        numero: leerInt(m['numero']),
        clienteId: leerTexto(m['clienteId']),
        clienteNombre: leerTexto(m['clienteNombre']),
        clienteTelefono: leerTexto(m['clienteTelefono']),
        equipo: Equipo.fromMap(m['equipo'] is Map ? Map<String, dynamic>.from(m['equipo'] as Map) : null),
        problema: leerTexto(m['problema']),
        notas: leerTexto(m['notas']),
        estado: EstadoOrden.desde(m['estado'] as String?),
        items: ItemLinea.listaDesde(m['items']),
        pagado: leerDouble(m['pagado']),
        fechaIngreso: leerFecha(m['fechaIngreso']) ?? DateTime.now(),
        fechaListo: leerFecha(m['fechaListo']),
        fechaEntrega: leerFecha(m['fechaEntrega']),
        fechaEstimada: leerFecha(m['fechaEstimada']),
        proximoServiceFecha: leerFecha(m['proximoServiceFecha']),
        proximoServiceKm: m['proximoServiceKm'] == null ? null : leerInt(m['proximoServiceKm']),
        recordatorioEnviado: m['recordatorioEnviado'] == true,
        facturaId: leerTextoONull(m['facturaId']),
      );

  /// Representación para guardar. Incluye campos derivados (`total`,
  /// `saldo`, `activa`, `keywords`) para poder consultarlos en Firestore.
  Map<String, dynamic> toMap() => {
        'numero': numero,
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        'clienteTelefono': clienteTelefono,
        'equipo': equipo.toMap(),
        'problema': problema.trim(),
        'notas': notas.trim(),
        'estado': estado.valor,
        'activa': estado.activo,
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'pagado': pagado,
        'saldo': estado == EstadoOrden.cancelado ? 0 : saldo,
        'fechaIngreso': fechaIngreso,
        'fechaListo': fechaListo,
        'fechaEntrega': fechaEntrega,
        'fechaEstimada': fechaEstimada,
        'proximoServiceFecha': proximoServiceFecha,
        'proximoServiceKm': proximoServiceKm,
        'recordatorioEnviado': recordatorioEnviado,
        // Se reescribe tal cual: las reglas impiden que la app lo cambie.
        if (facturaId != null) 'facturaId': facturaId,
        'keywords': Busqueda.keywords([
          clienteNombre,
          equipo.descripcion,
          equipo.identificador,
          numero.toString(),
        ]),
      };

  Orden copyWith({
    int? numero,
    String? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    Equipo? equipo,
    String? problema,
    String? notas,
    EstadoOrden? estado,
    List<ItemLinea>? items,
    double? pagado,
    DateTime? fechaIngreso,
    DateTime? fechaListo,
    DateTime? fechaEntrega,
    DateTime? fechaEstimada,
    bool limpiarFechaEstimada = false,
    DateTime? proximoServiceFecha,
    int? proximoServiceKm,
    bool? recordatorioEnviado,
    bool limpiarProximoService = false,
  }) =>
      Orden(
        id: id,
        numero: numero ?? this.numero,
        clienteId: clienteId ?? this.clienteId,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        clienteTelefono: clienteTelefono ?? this.clienteTelefono,
        equipo: equipo ?? this.equipo,
        problema: problema ?? this.problema,
        notas: notas ?? this.notas,
        estado: estado ?? this.estado,
        items: items ?? this.items,
        pagado: pagado ?? this.pagado,
        fechaIngreso: fechaIngreso ?? this.fechaIngreso,
        fechaListo: fechaListo ?? this.fechaListo,
        fechaEntrega: fechaEntrega ?? this.fechaEntrega,
        fechaEstimada: limpiarFechaEstimada ? null : (fechaEstimada ?? this.fechaEstimada),
        proximoServiceFecha: limpiarProximoService ? null : (proximoServiceFecha ?? this.proximoServiceFecha),
        proximoServiceKm: limpiarProximoService ? null : (proximoServiceKm ?? this.proximoServiceKm),
        recordatorioEnviado: recordatorioEnviado ?? this.recordatorioEnviado,
        facturaId: facturaId,
      );
}
