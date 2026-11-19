import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models/negocio.dart';
import '../data/repositories/caja_repository.dart';
import '../data/repositories/clientes_repository.dart';
import '../data/repositories/equipo_repository.dart';
import '../data/repositories/facturacion_repository.dart';
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
    required this.equipo,
    required this.facturacion,
    required this.esSuperadmin,
  });

  factory Sesion.crear({
    required User usuario,
    required Negocio negocio,
    required RolMiembro rol,
    bool esSuperadmin = false,
  }) {
    final db = Db(negocio.id);
    final productos = ProductosRepository(db, usuarioUid: usuario.uid, usuarioEmail: usuario.email ?? '');
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
      equipo: EquipoRepository(db),
      facturacion: FacturacionRepository(db),
      esSuperadmin: esSuperadmin,
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
  final EquipoRepository equipo;
  final FacturacionRepository facturacion;

  /// Administrador de la plataforma (vos): ve el panel de administración.
  final bool esSuperadmin;

  /// ¿El usuario actual puede hacer [p]? (La UI usa esto para mostrar u
  /// ocultar acciones; las reglas de Firestore lo garantizan en el servidor.)
  bool puede(Permiso p) => rol.puede(p);

  Sesion _con({Negocio? negocio, RolMiembro? rol}) => Sesion._(
        usuario: usuario,
        negocio: negocio ?? this.negocio,
        rol: rol ?? this.rol,
        db: db,
        clientes: clientes,
        ordenes: ordenes,
        presupuestos: presupuestos,
        caja: caja,
        negocioRepo: negocioRepo,
        productos: productos,
        equipo: equipo,
        facturacion: facturacion,
        esSuperadmin: esSuperadmin,
      );

  static Sesion of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SesionScope>();
    final sesion = scope?.notifier?.sesion;
    assert(sesion != null, 'No hay una sesión iniciada');
    return sesion!;
  }
}

/// Mantiene la sesión activa y la sincroniza con Firestore: el documento
/// del negocio (plan, datos) y el registro de miembro del usuario (rol, o
/// si lo quitaron del equipo).
class SesionController extends ChangeNotifier {
  Sesion? _sesion;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _accesoPerdido = false;

  Sesion? get sesion => _sesion;

  /// `true` si el usuario dejó de ser miembro mientras usaba la app.
  /// La sesión anterior queda disponible hasta que se inicie otra.
  bool get accesoPerdido => _accesoPerdido;

  void iniciar(Sesion sesion) {
    _cancelar();
    _sesion = sesion;
    _accesoPerdido = false;
    _subs.add(sesion.negocioRepo.observar().listen((n) {
      final actual = _sesion;
      if (n != null && actual != null && actual.negocio.id == n.id) {
        _sesion = actual._con(negocio: n);
        notifyListeners();
      }
    }, onError: (_) {}));
    _subs.add(sesion.db.miembros.doc(sesion.usuario.uid).snapshots().listen((d) {
      final actual = _sesion;
      if (actual == null) return;
      if (!d.exists) {
        _perderAcceso();
        return;
      }
      final rol = RolMiembro.desde(d.data()?['rol'] as String?);
      if (rol != actual.rol) {
        _sesion = actual._con(rol: rol);
        notifyListeners();
      }
    }, onError: (_) => _perderAcceso()));
    notifyListeners();
  }

  /// Se conserva la sesión anterior (las pantallas abiertas no se rompen
  /// mientras se cierran); el arranque detecta [accesoPerdido] y muestra el
  /// aviso correspondiente.
  void _perderAcceso() {
    if (_sesion == null || _accesoPerdido) return;
    _cancelar();
    _accesoPerdido = true;
    notifyListeners();
  }

  void cerrar() {
    _cancelar();
    _accesoPerdido = false;
    if (_sesion != null) {
      _sesion = null;
      notifyListeners();
    }
  }

  void _cancelar() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _cancelar();
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
