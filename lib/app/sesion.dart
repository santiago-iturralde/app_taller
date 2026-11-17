import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models/negocio.dart';
import '../data/repositories/caja_repository.dart';
import '../data/repositories/clientes_repository.dart';
import '../data/repositories/negocio_repository.dart';
import '../data/repositories/ordenes_repository.dart';
import '../data/repositories/presupuestos_repository.dart';
import '../data/repositories/productos_repository.dart';

/// Todo lo que una pantalla necesita saber del usuario y su negocio.
///
/// Se obtiene con `Sesion.of(context)` desde cualquier pantalla, diálogo o
/// panel. Cuando el negocio cambia en Firestore (por ejemplo, se activa el
/// plan PRO) las pantallas se reconstruyen solas.
class Sesion {
  Sesion._({
    required this.usuario,
    required this.negocio,
    required this.rol,
    required this.db,
    required this.clientes,
    required this.ordenes,
    required this.presupuestos,
    required this.caja,
    required this.negocioRepo,
    required this.productos,
  });

  factory Sesion.crear({required User usuario, required Negocio negocio, required RolMiembro rol}) {
    final db = Db(negocio.id);
    final productos = ProductosRepository(db);
    return Sesion._(
      usuario: usuario,
      negocio: negocio,
      rol: rol,
      db: db,
      clientes: ClientesRepository(db),
      ordenes: OrdenesRepository(db, productos),
      presupuestos: PresupuestosRepository(db, productos),
      caja: CajaRepository(db, productos),
      negocioRepo: NegocioRepository(db),
      productos: productos,
    );
  }

  final User usuario;
  final Negocio negocio;
  final RolMiembro rol;
  final Db db;
  final ClientesRepository clientes;
  final OrdenesRepository ordenes;
  final PresupuestosRepository presupuestos;
  final CajaRepository caja;
  final NegocioRepository negocioRepo;
  final ProductosRepository productos;

  Sesion _conNegocio(Negocio n) => Sesion._(
        usuario: usuario,
        negocio: n,
        rol: rol,
        db: db,
        clientes: clientes,
        ordenes: ordenes,
        presupuestos: presupuestos,
        caja: caja,
        negocioRepo: negocioRepo,
        productos: productos,
      );

  static Sesion of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SesionScope>();
    final sesion = scope?.notifier?.sesion;
    assert(sesion != null, 'No hay una sesión iniciada');
    return sesion!;
  }
}

/// Mantiene la sesión activa y la sincroniza con el documento del negocio.
class SesionController extends ChangeNotifier {
  Sesion? _sesion;
  StreamSubscription<Negocio?>? _sub;

  Sesion? get sesion => _sesion;

  void iniciar(Sesion sesion) {
    _sub?.cancel();
    _sesion = sesion;
    _sub = sesion.negocioRepo.observar().listen((n) {
      final actual = _sesion;
      if (n != null && actual != null && actual.negocio.id == n.id) {
        _sesion = actual._conNegocio(n);
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void cerrar() {
    _sub?.cancel();
    _sub = null;
    if (_sesion != null) {
      _sesion = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Se coloca por encima de `MaterialApp` para que todas las rutas,
/// diálogos y paneles tengan acceso a la sesión.
class SesionScope extends InheritedNotifier<SesionController> {
  const SesionScope({super.key, required SesionController controller, required super.child})
      : super(notifier: controller);

  static SesionController controller(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SesionScope>()!.notifier!;
}
