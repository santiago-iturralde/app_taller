import 'package:flutter_test/flutter_test.dart';
import 'package:taller_reparaciones/data/models/caja.dart';
import 'package:taller_reparaciones/data/models/comunes.dart';
import 'package:taller_reparaciones/data/models/orden.dart';
import 'package:taller_reparaciones/data/models/producto.dart';

const aceite = ItemLinea(descripcion: 'Aceite 10W40', cantidad: 4, precioUnitario: 9000, productoId: 'aceite', costoUnitario: 6000);
const filtro = ItemLinea(descripcion: 'Filtro', precioUnitario: 7000, productoId: 'filtro');
const manoDeObra = ItemLinea(descripcion: 'Mano de obra', precioUnitario: 10000);

void main() {
  group('CalculoStock', () {
    test('consumo suma por producto e ignora ítems libres', () {
      final c = CalculoStock.consumo([aceite, filtro, manoDeObra, aceite.copyWith(cantidad: 1)]);
      expect(c, {'aceite': 5, 'filtro': 1});
    });

    test('crear un trabajo descuenta lo usado', () {
      expect(CalculoStock.diferencia(const [], [aceite, filtro]), {'aceite': -4, 'filtro': -1});
    });

    test('eliminar o cancelar devuelve lo usado', () {
      expect(CalculoStock.diferencia([aceite, filtro], const []), {'aceite': 4, 'filtro': 1});
    });

    test('editar cantidades ajusta sólo la diferencia', () {
      final d = CalculoStock.diferencia([aceite, filtro], [aceite.copyWith(cantidad: 5), manoDeObra]);
      expect(d, {'aceite': -1, 'filtro': 1});
    });

    test('sin cambios no genera movimientos', () {
      expect(CalculoStock.diferencia([aceite], [aceite.copyWith(precioUnitario: 1)]), isEmpty);
    });
  });

  group('Orden y stock', () {
    Orden orden(EstadoOrden estado) => Orden(
          id: 'o',
          numero: 1,
          clienteId: 'c',
          clienteNombre: 'X',
          items: const [aceite, manoDeObra],
          estado: estado,
          fechaIngreso: DateTime(2026),
        );

    test('un trabajo cancelado no consume stock', () {
      expect(orden(EstadoOrden.cancelado).itemsQueConsumenStock, isEmpty);
      expect(orden(EstadoOrden.enProceso).itemsQueConsumenStock, hasLength(2));
    });

    test('cancelar devuelve y reabrir vuelve a descontar', () {
      final activo = orden(EstadoOrden.enProceso);
      final cancelado = orden(EstadoOrden.cancelado);
      expect(CalculoStock.diferencia(activo.itemsQueConsumenStock, cancelado.itemsQueConsumenStock), {'aceite': 4});
      expect(CalculoStock.diferencia(cancelado.itemsQueConsumenStock, activo.itemsQueConsumenStock), {'aceite': -4});
    });

    test('el próximo service sobrevive al ida y vuelta por Map', () {
      final o = orden(EstadoOrden.entregado).copyWith(proximoServiceFecha: DateTime(2027, 3, 1), proximoServiceKm: 85000);
      final m = o.toMap();
      expect(m['recordatorioEnviado'], isFalse);
      final copia = Orden.fromMap('o', m);
      expect(copia.proximoServiceKm, 85000);
      expect(copia.tieneProximoService, isTrue);
    });
  });

  group('ItemLinea del catálogo', () {
    test('conserva el vínculo con el producto y el costo', () {
      final copia = ItemLinea.fromMap(aceite.toMap());
      expect(copia.productoId, 'aceite');
      expect(copia.costoUnitario, 6000);
      expect(copia.delCatalogo, isTrue);
    });

    test('un ítem libre no guarda campos de catálogo', () {
      expect(manoDeObra.toMap().containsKey('productoId'), isFalse);
    });
  });

  group('Producto', () {
    const p = Producto(id: 'p', nombre: 'Aceite', precio: 10000, costo: 7000, stock: 2, stockMinimo: 3);

    test('margen y stock bajo', () {
      expect(p.margen, closeTo(30, 0.001));
      expect(p.stockBajo, isTrue);
      expect(p.copyWith(stock: 10).stockBajo, isFalse);
      expect(p.copyWith(stock: 0).sinStock, isTrue);
    });

    test('un servicio nunca tiene stock bajo', () {
      const s = Producto(id: 's', nombre: 'MO', tipo: TipoProducto.servicio, stock: -5, stockMinimo: 1);
      expect(s.controlaStock, isFalse);
      expect(s.stockBajo, isFalse);
      expect(s.toMap()['stockBajo'], isFalse);
    });

    test('el formulario no puede pisar el stock', () {
      expect(p.toMap().containsKey('stock'), isFalse);
    });

    test('se convierte en ítem con su precio y costo', () {
      final i = p.comoItem();
      expect(i.productoId, 'p');
      expect(i.precioUnitario, 10000);
      expect(i.costoUnitario, 7000);
    });
  });

  test('Pago de venta guarda y lee sus ítems', () {
    final pago = Pago(id: 'x', numero: 3, monto: 43000, fecha: DateTime(2026), items: const [aceite, filtro]);
    final copia = Pago.fromMap('x', pago.toMap());
    expect(copia.esVenta, isTrue);
    expect(copia.items.first.productoId, 'aceite');
    expect(Pago(id: 'y', numero: 1, monto: 1, fecha: DateTime(2026)).toMap().containsKey('items'), isFalse);
  });
}
