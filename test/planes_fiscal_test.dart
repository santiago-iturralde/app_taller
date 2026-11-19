import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taller_reparaciones/core/utils/formato.dart';
import 'package:taller_reparaciones/data/models/caja.dart';
import 'package:taller_reparaciones/data/models/cambio_plan.dart';
import 'package:taller_reparaciones/data/models/fiscal.dart';
import 'package:taller_reparaciones/data/models/negocio.dart';
import 'package:taller_reparaciones/data/models/orden.dart';

Negocio _negocio(String plan, {DateTime? vence, bool prueba = false}) => Negocio.fromMap('n', {
      'plan': plan,
      if (vence != null) 'planVence': Timestamp.fromDate(vence),
      'prueba': prueba,
    });

void main() {
  group('Planes', () {
    final manana = DateTime.now().add(const Duration(days: 1));
    final ayer = DateTime.now().subtract(const Duration(days: 1));

    test('cada plan incluye lo de los anteriores', () {
      expect(Plan.gratis.incluye(FuncionPro.facturacion), isFalse);
      expect(Plan.basico.incluye(FuncionPro.facturacion), isTrue);
      expect(Plan.basico.incluye(FuncionPro.equipo), isFalse);
      for (final f in FuncionPro.values) {
        expect(Plan.pro.incluye(f), isTrue, reason: f.name);
      }
    });

    test('un plan vencido funciona como Gratis sin perder el plan contratado', () {
      final n = _negocio('pro', vence: ayer);
      expect(n.vencido, isTrue);
      expect(n.plan, Plan.pro);
      expect(n.planEfectivo, Plan.gratis);
      expect(n.permite(FuncionPro.reportes), isFalse);
    });

    test('plan vigente', () {
      final n = _negocio('basico', vence: manana);
      expect(n.vencido, isFalse);
      expect(n.permite(FuncionPro.facturacion), isTrue);
      expect(n.permite(FuncionPro.equipo), isFalse);
    });

    test('días restantes', () {
      final hoy = DateTime(2026, 11, 18, 22);
      expect(_negocio('pro', vence: DateTime(2026, 11, 25, 3)).diasRestantes(hoy), 7);
      expect(_negocio('pro', vence: DateTime(2026, 11, 18, 23)).diasRestantes(hoy), 0);
      expect(_negocio('free').diasRestantes(hoy), isNull);
    });

    test('valores desconocidos caen en Gratis', () {
      expect(Plan.desde('enterprise'), Plan.gratis);
      expect(Plan.desde('basico'), Plan.basico);
    });
  });

  group('Cambios de plan del administrador', () {
    final ahora = DateTime(2026, 11, 18, 12);

    test('suma meses respetando fin de mes', () {
      expect(sumarMeses(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(sumarMeses(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(sumarMeses(DateTime(2026, 11, 18), 12), DateTime(2027, 11, 18));
      expect(sumarMeses(DateTime(2026, 11, 30), 3), DateTime(2027, 2, 28));
    });

    test('renovar el mismo plan antes de vencer suma al tiempo restante', () {
      final c = CambioPlan.activar(_negocio('pro', vence: DateTime(2026, 12, 10, 12)), Plan.pro, 1, ahora: ahora);
      expect(c.vence, DateTime(2027, 1, 10, 12));
      expect(c.prueba, isFalse);
      expect(c.accion, 'activar');
    });

    test('plan vencido, prueba o cambio de plan: cuenta desde hoy', () {
      expect(CambioPlan.activar(_negocio('pro', vence: DateTime(2026, 10, 1)), Plan.pro, 1, ahora: ahora).vence,
          DateTime(2026, 12, 18, 12));
      expect(CambioPlan.activar(_negocio('basico', vence: DateTime(2026, 12, 10)), Plan.pro, 1, ahora: ahora).vence,
          DateTime(2026, 12, 18, 12));
      expect(CambioPlan.activar(_negocio('free'), Plan.basico, 6, ahora: ahora).vence, DateTime(2027, 5, 18, 12));
    });

    test('prueba y Gratis', () {
      final p = CambioPlan.prueba(7, ahora: ahora);
      expect((p.plan, p.prueba, p.vence), (Plan.pro, true, DateTime(2026, 11, 25, 12)));
      const g = CambioPlan.gratis();
      expect((g.plan, g.prueba, g.vence), (Plan.gratis, false, null));
    });

    test('valida meses, días y plan', () {
      final n = _negocio('free');
      expect(() => CambioPlan.activar(n, Plan.pro, 0), throwsArgumentError);
      expect(() => CambioPlan.activar(n, Plan.pro, 37), throwsArgumentError);
      expect(() => CambioPlan.activar(n, Plan.gratis, 1), throwsArgumentError);
      expect(() => CambioPlan.prueba(0), throwsArgumentError);
      expect(() => CambioPlan.prueba(91), throwsArgumentError);
    });
  });

  group('Datos fiscales', () {
    test('ida y vuelta con alícuota entera para las reglas', () {
      const c = ConfigFiscal(
        razonSocial: 'Lubri SRL',
        cuit: '33-69345023-9',
        condicionIva: CondicionIva.responsableInscripto,
        puntoVenta: 3,
        alicuotaIva: 21,
        ambiente: AmbienteArca.produccion,
        concepto: ConceptoFactura.servicios,
      );
      final m = c.toMap();
      expect(m['cuit'], '33693450239');
      expect(m['alicuotaIva'], isA<int>());
      expect(m['concepto'], 2);
      final copia = ConfigFiscal.fromMap(m);
      expect(copia.ambiente, AmbienteArca.produccion);
      expect(copia.condicionIva, CondicionIva.responsableInscripto);
      expect(copia.completa, isTrue);
      expect(const ConfigFiscal(alicuotaIva: 10.5).toMap()['alicuotaIva'], 10.5);
    });

    test('CUIT con dígito verificador (igual que el servidor)', () {
      expect(cuitValido('33693450239'), isTrue);
      expect(cuitValido('33693450238'), isFalse);
      expect(cuitValido('1234'), isFalse);
    });

    test('letra según emisor y receptor', () {
      expect(ReceptorFactura.letraPara(CondicionIva.monotributo, CondicionIva.responsableInscripto), 'C');
      expect(ReceptorFactura.letraPara(CondicionIva.responsableInscripto, CondicionIva.responsableInscripto), 'A');
      expect(ReceptorFactura.letraPara(CondicionIva.responsableInscripto, CondicionIva.monotributo), 'A');
      expect(ReceptorFactura.letraPara(CondicionIva.responsableInscripto, CondicionIva.consumidorFinal), 'B');
    });
  });

  test('Factura: numeración y documento del receptor', () {
    final f = Factura.fromMap('f', {
      'estado': 'autorizada',
      'tipo': 6,
      'letra': 'B',
      'puntoVenta': 3,
      'numero': 148,
      'receptor': {'nombre': 'Juan', 'docTipo': 96, 'docNro': 30111222, 'condicionIva': 'consumidor_final'},
      'importes': {'total': 1210, 'neto': 1000, 'iva': 210, 'alicuota': 21},
      'origen': {'tipo': 'orden', 'id': 'o1', 'numero': 7},
      'asociada': {'letra': 'B', 'puntoVenta': 3, 'numero': 147},
    });
    expect(f.numeroCompleto, '00003-00000148');
    expect(f.codigo, '06');
    expect(f.nombreTipo, 'Factura B');
    expect(f.documentoReceptor, 'DNI 30111222');
    expect(f.discriminaIva, isFalse);
    expect(f.asociada, 'B 00003-00000147');
    expect(f.estado, EstadoFactura.autorizada);
  });

  test('recibos del talonario anterior: se marcan y conservan su número viejo', () {
    final viejo = Pago.fromMap('p', {'numero': 3, 'monto': 500, 'numeroAnterior': '20250312-101530', 'excluirDeCaja': true});
    expect(viejo.delSistemaAnterior, isTrue);
    expect(viejo.cuentaEnCaja, isFalse);
    expect(viejo.toMap()['numeroAnterior'], '20250312-101530');
    expect(Pago.fromMap('p', {'numero': 4, 'monto': 1}).delSistemaAnterior, isFalse);
    expect(Formato.numeroRecibo(0, ''), 's/n');
    expect(Formato.numeroRecibo(7, 'x'), '00007');
    expect(Pago.fromMap('p', {'numero': 7, 'monto': 1}).toMap().containsKey('numeroAnterior'), isFalse);
  });

  group('Marca de facturado', () {
    test('el trabajo conserva la factura al guardarse', () {
      final o = Orden.fromMap('o', {'numero': 1, 'facturaId': 'f1', 'fechaIngreso': Timestamp.now()});
      expect(o.toMap()['facturaId'], 'f1');
      expect(o.copyWith(problema: 'x').facturaId, 'f1');
      expect(Orden.fromMap('o', {'numero': 1}).toMap().containsKey('facturaId'), isFalse);
    });

    test('qué cobros se pueden facturar', () {
      Pago pago({String? ordenId, String? facturaId, bool anulado = false, bool excluir = false}) => Pago(
            id: 'p',
            numero: 1,
            monto: 100,
            fecha: DateTime(2026),
            ordenId: ordenId,
            facturaId: facturaId,
            anulado: anulado,
            excluirDeCaja: excluir,
          );
      expect(pago().facturable, isTrue);
      expect(pago(ordenId: 'o').facturable, isFalse); // se factura el trabajo
      expect(pago(facturaId: 'f').facturable, isFalse);
      expect(pago(anulado: true).facturable, isFalse);
      expect(pago(excluir: true).facturable, isFalse);
    });
  });
}
