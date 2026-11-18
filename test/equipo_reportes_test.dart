import 'package:flutter_test/flutter_test.dart';
import 'package:taller_reparaciones/data/models/caja.dart';
import 'package:taller_reparaciones/data/models/comunes.dart';
import 'package:taller_reparaciones/data/models/equipo.dart';
import 'package:taller_reparaciones/data/models/negocio.dart';
import 'package:taller_reparaciones/data/models/orden.dart';
import 'package:taller_reparaciones/data/models/producto.dart';
import 'package:taller_reparaciones/data/resumen_mes.dart';

Orden _orden(List<ItemLinea> items, {EstadoOrden estado = EstadoOrden.entregado}) => Orden(
      id: 'o',
      numero: 1,
      clienteId: 'c',
      clienteNombre: 'X',
      items: items,
      estado: estado,
      fechaIngreso: DateTime(2026, 11, 2),
    );

Pago _venta(List<ItemLinea> items, {bool anulado = false}) =>
    Pago(id: 'p', numero: 1, monto: ItemLinea.total(items), fecha: DateTime(2026, 11, 3), items: items, anulado: anulado);

void main() {
  group('Permisos por rol', () {
    test('el empleado no accede a nada administrativo', () {
      for (final p in Permiso.values) {
        expect(RolMiembro.empleado.puede(p), isFalse, reason: p.name);
      }
    });

    test('el dueño puede todo', () {
      for (final p in Permiso.values) {
        expect(RolMiembro.duenio.puede(p), isTrue, reason: p.name);
      }
    });

    test('el admin administra pero no gestiona otros admins', () {
      expect(RolMiembro.admin.puede(Permiso.verReportes), isTrue);
      expect(RolMiembro.admin.puede(Permiso.gestionarEquipo), isTrue);
      expect(RolMiembro.admin.puede(Permiso.invitarAdministradores), isFalse);
      expect(RolMiembro.admin.puede(Permiso.cambiarRoles), isFalse);
    });

    test('roles con el mismo valor que esperan las reglas', () {
      expect(RolMiembro.duenio.valor, 'owner');
      expect(RolMiembro.desde('admin'), RolMiembro.admin);
      expect(RolMiembro.desde('cualquier cosa'), RolMiembro.empleado);
    });
  });

  group('Invitacion', () {
    test('el ID es determinista y con el email en minúsculas', () {
      expect(Invitacion.idPara('neg1', '  Juan.Perez@Mail.COM '), 'neg1_juan.perez@mail.com');
    });

    test('valida emails', () {
      expect(Invitacion.emailValido('ana@taller.com.ar'), isTrue);
      expect(Invitacion.emailValido('ana@taller'), isFalse);
      expect(Invitacion.emailValido('sin arroba'), isFalse);
    });

    test('ida y vuelta por Map normaliza el email', () {
      final i = Invitacion(
        negocioId: 'n',
        negocioNombre: 'Lubri',
        email: 'Ana@X.com',
        rol: RolMiembro.empleado,
        vence: DateTime(2030),
      );
      final m = i.toMap();
      expect(m['email'], 'ana@x.com');
      expect(m['rol'], 'empleado');
      expect(Invitacion.fromMap(m).id, 'n_ana@x.com');
      expect(i.vencida, isFalse);
    });
  });

  group('ResumenProductos', () {
    const aceite = ItemLinea(descripcion: 'Aceite', cantidad: 4, precioUnitario: 10000, productoId: 'a', costoUnitario: 7000);
    const filtro = ItemLinea(descripcion: 'Filtro', precioUnitario: 8000, productoId: 'f');
    const mo = ItemLinea(descripcion: 'Mano de obra', precioUnitario: 15000);

    final r = ResumenProductos(
      entregadas: [
        _orden([aceite, filtro, mo]),
        _orden([mo.copyWith(descripcion: 'mano de obra')]), // se agrupa sin importar mayúsculas
        _orden([aceite], estado: EstadoOrden.enProceso), // no entregado: no cuenta
      ],
      pagos: [
        _venta([aceite.copyWith(cantidad: 1)]),
        _venta([filtro], anulado: true), // anulada: no cuenta
      ],
    );

    test('agrupa y ordena por facturado', () {
      expect(r.ranking.map((v) => v.descripcion).toList(), ['Aceite', 'Mano de obra', 'Filtro']);
      final aceiteR = r.ranking.first;
      expect(aceiteR.cantidad, 5);
      expect(aceiteR.facturado, 50000);
      expect(aceiteR.ganancia, 15000);
      expect(aceiteR.margen, closeTo(30, 0.001));
      expect(r.ranking[1].cantidad, 2);
    });

    test('la ganancia sólo considera ítems con costo', () {
      expect(r.facturado, 50000 + 30000 + 8000);
      expect(r.facturadoConCosto, 50000);
      expect(r.gananciaBruta, 15000);
      expect(r.facturadoSinCosto, 38000);
      expect(r.ranking.last.margen, isNull);
    });
  });

  test('ValorInventario', () {
    final v = ValorInventario(const [
      Producto(id: '1', nombre: 'A', precio: 100, costo: 60, stock: 10, stockMinimo: 2),
      Producto(id: '2', nombre: 'B', precio: 50, stock: 4, stockMinimo: 5), // sin costo, stock bajo
      Producto(id: '3', nombre: 'C', precio: 80, costo: 40, stock: -2), // negativo: no suma
      Producto(id: '4', nombre: 'MO', tipo: TipoProducto.servicio, precio: 9999, stock: 100),
    ]);
    expect(v.unidades, 14);
    expect(v.alCosto, 600);
    expect(v.aPrecioDeVenta, 1200);
    expect(v.conStockBajo, 2); // B y C
    expect(v.productosSinCosto, 1);
  });
}
