import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taller_reparaciones/data/migracion_legacy.dart';
import 'package:taller_reparaciones/data/models/caja.dart';
import 'package:taller_reparaciones/data/models/comunes.dart';
import 'package:taller_reparaciones/data/models/negocio.dart';
import 'package:taller_reparaciones/data/models/orden.dart';
import 'package:taller_reparaciones/data/models/presupuesto.dart';
import 'package:taller_reparaciones/data/resumen_mes.dart';

Orden _orden({List<ItemLinea> items = const [], double pagado = 0, EstadoOrden estado = EstadoOrden.recibido}) => Orden(
      id: 'o1',
      numero: 1,
      clienteId: 'c1',
      clienteNombre: 'Juan Pérez',
      equipo: const Equipo(descripcion: 'Amoladora Bosch', identificador: 'ab123'),
      items: items,
      pagado: pagado,
      estado: estado,
      fechaIngreso: DateTime(2026, 11, 1),
    );

void main() {
  group('ItemLinea', () {
    test('calcula subtotal y total redondeado', () {
      const items = [
        ItemLinea(descripcion: 'Aceite', cantidad: 4, precioUnitario: 10500.333),
        ItemLinea(descripcion: 'Filtro', precioUnitario: 8000),
      ];
      expect(items.first.subtotal, 42001.33);
      expect(ItemLinea.total(items), 50001.33);
    });

    test('lee el formato viejo (desc / precio)', () {
      final i = ItemLinea.fromMap({'desc': 'Rodamiento', 'cantidad': 2, 'precio': 1500});
      expect(i.descripcion, 'Rodamiento');
      expect(i.subtotal, 3000);
    });
  });

  group('Orden', () {
    test('saldo y estado de pago', () {
      final o = _orden(items: const [ItemLinea(descripcion: 'MO', precioUnitario: 10000)], pagado: 4000);
      expect(o.total, 10000);
      expect(o.saldo, 6000);
      expect(o.pagadoCompleto, isFalse);
      expect(o.copyWith(pagado: 10000).pagadoCompleto, isTrue);
    });

    test('sin ítems está "a presupuestar" y no debe nada', () {
      final o = _orden();
      expect(o.sinPresupuestar, isTrue);
      expect(o.saldo, 0);
    });

    test('el saldo nunca es negativo', () {
      final o = _orden(items: const [ItemLinea(descripcion: 'MO', precioUnitario: 100)], pagado: 150);
      expect(o.saldo, 0);
    });

    test('toMap guarda campos derivados para consultar', () {
      final m = _orden(items: const [ItemLinea(descripcion: 'MO', precioUnitario: 100)]).toMap();
      expect(m['activa'], isTrue);
      expect(m['total'], 100);
      expect(m['saldo'], 100);
      expect(m['equipo']['identificador'], 'AB123');
      expect(m['keywords'], containsAll(['juan', 'perez', 'amoladora', 'ab123']));
    });

    test('cancelado no deja saldo pendiente', () {
      final m = _orden(items: const [ItemLinea(descripcion: 'MO', precioUnitario: 100)], estado: EstadoOrden.cancelado).toMap();
      expect(m['activa'], isFalse);
      expect(m['saldo'], 0);
    });

    test('ida y vuelta por Map conserva los datos', () {
      final o = _orden(items: const [ItemLinea(descripcion: 'MO', cantidad: 2, precioUnitario: 50)], pagado: 30);
      final copia = Orden.fromMap(o.id, o.toMap());
      expect(copia.total, o.total);
      expect(copia.saldo, o.saldo);
      expect(copia.equipo.descripcion, o.equipo.descripcion);
    });

    test('siguiente estado sugerido', () {
      expect(EstadoOrden.recibido.siguiente, EstadoOrden.enProceso);
      expect(EstadoOrden.listo.siguiente, EstadoOrden.entregado);
      expect(EstadoOrden.entregado.siguiente, isNull);
    });
  });

  test('Presupuesto vence según validez', () {
    final p = Presupuesto(id: 'p', numero: 1, clienteId: 'c', clienteNombre: 'X', fecha: DateTime(2020), validezDias: 10);
    expect(p.vence, DateTime(2020, 1, 11));
    expect(p.vencido, isTrue);
    expect(p.copyWith(estado: EstadoPresupuesto.aprobado).vencido, isFalse);
  });

  group('Negocio', () {
    test('el plan PRO vencido no habilita funciones', () {
      final n = Negocio.fromMap('n', {'plan': 'pro', 'planVence': Timestamp.fromDate(DateTime(2020))});
      expect(n.esPro, isFalse);
      expect(Negocio.fromMap('n', {'plan': 'pro'}).esPro, isTrue);
    });

    test('datosEditables nunca incluye el plan', () {
      final m = Negocio.fromMap('n', {'plan': 'pro', 'nombre': 'X'}).datosEditables();
      expect(m.keys, isNot(contains('plan')));
      expect(m.keys, isNot(contains('planVence')));
      expect(m.keys, isNot(contains('ownerUid')));
    });

    test('usa la plantilla por defecto si la propia está vacía', () {
      final n = Negocio.fromMap('n', {'plantillas': {'listo': '  '}});
      expect(n.plantilla(PlantillasMensaje.listo), PlantillasMensaje.porDefecto[PlantillasMensaje.listo]);
    });
  });

  group('PlanMigracion', () {
    final plan = PlanMigracion.desde(
      clientes: [
        (id: 'c1', data: {'nombre': 'Ana López', 'telefono': '1155443322', 'fechaRegistro': Timestamp.fromDate(DateTime(2025, 1, 1))}),
      ],
      reparaciones: [
        // Desordenadas a propósito: se numeran por fecha.
        (id: 'r2', data: {'clienteId': 'c1', 'maquina': 'Taladro', 'problema': 'No gira', 'precio': 5000, 'estado': 'completada', 'estadoPago': 'pagado', 'fechaIngreso': Timestamp.fromDate(DateTime(2025, 3, 1))}),
        (id: 'r1', data: {'clienteId': 'c1', 'maquina': 'Amoladora', 'problema': 'Carbones', 'precio': 3000, 'estado': 'completada', 'estadoPago': 'pendiente', 'fechaIngreso': Timestamp.fromDate(DateTime(2025, 2, 1))}),
        (id: 'r3', data: {'clienteId': 'cX', 'maquina': 'Sierra', 'problema': '-', 'precio': '0', 'estado': 'pendiente', 'estadoPago': 'pendiente', 'fechaIngreso': Timestamp.fromDate(DateTime(2025, 4, 1))}),
      ],
      presupuestos: [
        (id: 'p1', data: {'clienteId': 'c1', 'items': [{'desc': 'Bobinado', 'cantidad': 1, 'precio': 20000}], 'total': 20000, 'fecha': Timestamp.fromDate(DateTime(2025, 2, 10))}),
      ],
      egresos: [
        (id: 'e1', data: {'descripcion': 'Repuestos', 'monto': 1000, 'categoria': 'Repuestos', 'fecha': Timestamp.fromDate(DateTime(2025, 2, 5))}),
      ],
      recibos: [
        (id: 'rc1', data: {'clienteId': 'c1', 'clienteNombre': 'Ana López', 'monto': 5000, 'concepto': 'Taladro', 'nroRecibo': '20250301-1', 'fecha': Timestamp.fromDate(DateTime(2025, 3, 2))}),
      ],
    );

    Map<String, dynamic> doc(String col, String id) => plan.escrituras.firstWhere((e) => e.coleccion == col && e.id == id).data;

    test('migra todo y fija los contadores', () {
      expect(plan.cantidad('clientes'), 1);
      expect(plan.cantidad('ordenes'), 3);
      expect(plan.cantidad('presupuestos'), 1);
      expect(plan.cantidad('gastos'), 1);
      expect(plan.cantidad('pagos'), 2); // 1 reparación pagada + 1 recibo
      expect(plan.contadores, {'ordenes': 3, 'presupuestos': 1, 'pagos': 2});
    });

    test('numera los trabajos por fecha de ingreso', () {
      expect(doc('ordenes', 'r1')['numero'], 1);
      expect(doc('ordenes', 'r2')['numero'], 2);
      expect(doc('ordenes', 'r3')['numero'], 3);
    });

    test('traduce estados y pagos', () {
      expect(doc('ordenes', 'r2')['estado'], EstadoOrden.entregado.valor);
      expect(doc('ordenes', 'r2')['saldo'], 0);
      expect(doc('ordenes', 'r1')['estado'], EstadoOrden.listo.valor);
      expect(doc('ordenes', 'r1')['saldo'], 3000);
      expect(doc('ordenes', 'r3')['estado'], EstadoOrden.enProceso.valor);
      expect(doc('ordenes', 'r3')['clienteNombre'], 'Cliente sin registrar');
    });

    test('los recibos viejos se conservan pero no suman a caja', () {
      final recibo = doc('pagos', 'mig_rec_rc1');
      expect(recibo['excluirDeCaja'], isTrue);
      expect(recibo['numeroAnterior'], '20250301-1');
      expect(doc('pagos', 'mig_rep_r2')['excluirDeCaja'], isFalse);
      // Numeración de cobros por fecha: reparación (1/3) antes que recibo (2/3).
      expect(doc('pagos', 'mig_rep_r2')['numero'], 1);
      expect(recibo['numero'], 2);
    });

    test('presupuestos viejos leen ítems con formato anterior', () {
      expect(doc('presupuestos', 'p1')['total'], 20000);
      expect(doc('presupuestos', 'p1')['clienteNombre'], 'Ana López');
    });

    test('es determinista (se puede reintentar sin duplicar)', () {
      final ids = plan.escrituras.map((e) => '${e.coleccion}/${e.id}').toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  test('ResumenMes calcula indicadores', () {
    Pago pago(double monto, MedioPago medio, {bool anulado = false, bool excluir = false}) => Pago(
          id: '',
          numero: 0,
          monto: monto,
          fecha: DateTime(2026, 11, 5),
          medio: medio,
          anulado: anulado,
          excluirDeCaja: excluir,
        );
    final r = ResumenMes(
      pagos: [
        pago(1000, MedioPago.efectivo),
        pago(3000, MedioPago.transferencia),
        pago(500, MedioPago.efectivo),
        pago(9999, MedioPago.efectivo, anulado: true),
        pago(7777, MedioPago.otro, excluir: true),
      ],
      pagosMesAnterior: [pago(3600, MedioPago.efectivo)],
      gastos: [
        Gasto(id: '', descripcion: 'a', monto: 800, categoria: 'Repuestos', fecha: DateTime(2026, 11, 2)),
        Gasto(id: '', descripcion: 'b', monto: 200, categoria: 'Otros', fecha: DateTime(2026, 11, 3)),
      ],
      entregadas: [
        _orden(items: const [ItemLinea(descripcion: 'x', precioUnitario: 2000)], estado: EstadoOrden.entregado),
        _orden(items: const [ItemLinea(descripcion: 'y', precioUnitario: 4000)], estado: EstadoOrden.entregado),
      ],
    );
    expect(r.cobrado, 4500);
    expect(r.gastado, 1000);
    expect(r.resultado, 3500);
    expect(r.variacionCobrado, closeTo(25, 0.001));
    expect(r.trabajosEntregados, 2);
    expect(r.ticketPromedio, 3000);
    expect(r.porMedio.keys.first, MedioPago.transferencia); // ordenado de mayor a menor
    expect(r.porMedio[MedioPago.efectivo], 1500);
    expect(r.gastosPorCategoria, {'Repuestos': 800, 'Otros': 200});
  });
}
