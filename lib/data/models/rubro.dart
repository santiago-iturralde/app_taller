import 'package:flutter/material.dart';

/// Configuración que adapta el sistema a cada tipo de negocio.
///
/// El motor (trabajos, clientes, caja) es el mismo para todos; el rubro
/// sólo cambia vocabulario, campos visibles y valores por defecto.
@immutable
class Rubro {
  const Rubro({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icono,
    required this.equipo,
    required this.equipoPlural,
    required this.hintEquipo,
    required this.identificador,
    required this.hintIdentificador,
    required this.hintProblema,
    this.usaKilometraje = false,
    required this.categoriasGastos,
    this.sugerenciasItems = const ['Mano de obra', 'Repuestos'],
  });

  /// Atajos que aparecen al cargar ítems de un trabajo o presupuesto.
  final List<String> sugerenciasItems;

  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;

  /// Cómo se llama lo que el cliente trae: "Máquina", "Vehículo", "Equipo"…
  final String equipo;
  final String equipoPlural;
  final String hintEquipo;

  /// Dato que identifica al equipo: patente, N° de serie, IMEI…
  final String identificador;
  final String hintIdentificador;

  final String hintProblema;
  final bool usaKilometraje;
  final List<String> categoriasGastos;

  static const _gastosBase = ['Repuestos', 'Insumos', 'Alquiler', 'Servicios', 'Sueldos', 'Impuestos', 'Otros'];

  static const herramientas = Rubro(
    id: 'herramientas',
    nombre: 'Reparación de herramientas',
    descripcion: 'Herramientas eléctricas, máquinas y motores',
    icono: Icons.handyman_outlined,
    equipo: 'Máquina',
    equipoPlural: 'Máquinas',
    hintEquipo: 'Ej: Amoladora Bosch GWS 850',
    identificador: 'N° de serie',
    hintIdentificador: 'Opcional',
    hintProblema: 'Ej: No arranca, hace ruido al girar',
    categoriasGastos: _gastosBase,
  );

  static const lubricentro = Rubro(
    id: 'lubricentro',
    nombre: 'Lubricentro',
    descripcion: 'Cambio de aceite, filtros y service',
    icono: Icons.oil_barrel_outlined,
    equipo: 'Vehículo',
    equipoPlural: 'Vehículos',
    hintEquipo: 'Ej: Toyota Corolla 2018',
    identificador: 'Patente',
    hintIdentificador: 'Ej: AB123CD',
    hintProblema: 'Ej: Cambio de aceite y filtros',
    usaKilometraje: true,
    categoriasGastos: ['Aceites', 'Filtros', 'Insumos', 'Alquiler', 'Servicios', 'Sueldos', 'Impuestos', 'Otros'],
    sugerenciasItems: ['Aceite', 'Filtro de aceite', 'Filtro de aire', 'Filtro de habitáculo', 'Mano de obra'],
  );

  static const mecanica = Rubro(
    id: 'mecanica',
    nombre: 'Taller mecánico',
    descripcion: 'Mecánica general, frenos, tren delantero',
    icono: Icons.car_repair_outlined,
    equipo: 'Vehículo',
    equipoPlural: 'Vehículos',
    hintEquipo: 'Ej: Ford Ranger 2020',
    identificador: 'Patente',
    hintIdentificador: 'Ej: AB123CD',
    hintProblema: 'Ej: Ruido en el tren delantero',
    usaKilometraje: true,
    categoriasGastos: _gastosBase,
  );

  static const motos = Rubro(
    id: 'motos',
    nombre: 'Taller de motos',
    descripcion: 'Motos, cuatriciclos y bicicletas',
    icono: Icons.two_wheeler_outlined,
    equipo: 'Moto',
    equipoPlural: 'Motos',
    hintEquipo: 'Ej: Honda CG 150',
    identificador: 'Patente',
    hintIdentificador: 'Ej: A123BCD',
    hintProblema: 'Ej: Service de los 10.000 km',
    usaKilometraje: true,
    categoriasGastos: _gastosBase,
  );

  static const celulares = Rubro(
    id: 'celulares',
    nombre: 'Servicio técnico de celulares',
    descripcion: 'Celulares, tablets y accesorios',
    icono: Icons.smartphone_outlined,
    equipo: 'Equipo',
    equipoPlural: 'Equipos',
    hintEquipo: 'Ej: Samsung Galaxy A54',
    identificador: 'IMEI / N° de serie',
    hintIdentificador: 'Opcional',
    hintProblema: 'Ej: Pantalla rota, no carga',
    categoriasGastos: _gastosBase,
  );

  static const computacion = Rubro(
    id: 'computacion',
    nombre: 'Servicio técnico de PC',
    descripcion: 'Notebooks, PC, impresoras',
    icono: Icons.computer_outlined,
    equipo: 'Equipo',
    equipoPlural: 'Equipos',
    hintEquipo: 'Ej: Notebook Lenovo IdeaPad 3',
    identificador: 'N° de serie',
    hintIdentificador: 'Opcional',
    hintProblema: 'Ej: Lenta, no enciende',
    categoriasGastos: _gastosBase,
  );

  static const electrodomesticos = Rubro(
    id: 'electrodomesticos',
    nombre: 'Electrodomésticos',
    descripcion: 'Lavarropas, heladeras, aires',
    icono: Icons.kitchen_outlined,
    equipo: 'Artefacto',
    equipoPlural: 'Artefactos',
    hintEquipo: 'Ej: Lavarropas Drean Next 8.14',
    identificador: 'N° de serie',
    hintIdentificador: 'Opcional',
    hintProblema: 'Ej: No centrifuga',
    categoriasGastos: _gastosBase,
  );

  static const otro = Rubro(
    id: 'otro',
    nombre: 'Otro rubro',
    descripcion: 'Cualquier negocio de servicios',
    icono: Icons.storefront_outlined,
    equipo: 'Equipo',
    equipoPlural: 'Equipos',
    hintEquipo: 'Qué trae el cliente',
    identificador: 'Identificación',
    hintIdentificador: 'Opcional',
    hintProblema: 'Qué hay que hacer',
    categoriasGastos: _gastosBase,
  );

  static const todos = [herramientas, lubricentro, mecanica, motos, celulares, computacion, electrodomesticos, otro];

  static Rubro porId(String? id) => todos.firstWhere((r) => r.id == id, orElse: () => otro);
}
