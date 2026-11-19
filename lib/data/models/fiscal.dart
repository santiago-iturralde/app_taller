import 'comunes.dart';

/// Condición frente al IVA. Los valores coinciden con los del servidor.
enum CondicionIva {
  responsableInscripto('responsable_inscripto', 'Responsable inscripto'),
  monotributo('monotributo', 'Monotributista'),
  exento('exento', 'IVA exento'),
  consumidorFinal('consumidor_final', 'Consumidor final'),
  noCategorizado('no_categorizado', 'No categorizado');

  const CondicionIva(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  static CondicionIva desde(String? v, {CondicionIva porDefecto = CondicionIva.consumidorFinal}) =>
      values.firstWhere((c) => c.valor == v, orElse: () => porDefecto);

  /// Condiciones válidas para quien emite.
  static const emisores = [responsableInscripto, monotributo, exento];
}

enum AmbienteArca {
  homologacion('homologacion', 'Pruebas (homologación)'),
  produccion('produccion', 'Producción (facturas reales)');

  const AmbienteArca(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  static AmbienteArca desde(String? v) => v == 'produccion' ? produccion : homologacion;
}

enum ConceptoFactura {
  productos(1, 'Productos'),
  servicios(2, 'Servicios'),
  ambos(3, 'Productos y servicios');

  const ConceptoFactura(this.valor, this.etiqueta);
  final int valor;
  final String etiqueta;

  static ConceptoFactura desde(Object? v) => values.firstWhere((c) => c.valor == leerInt(v), orElse: () => ambos);
}

/// Datos fiscales del negocio (negocios/{id}/meta/fiscal).
class ConfigFiscal {
  const ConfigFiscal({
    this.razonSocial = '',
    this.cuit = '',
    this.condicionIva = CondicionIva.monotributo,
    this.domicilio = '',
    this.ingresosBrutos = '',
    this.inicioActividades = '',
    this.puntoVenta = 1,
    this.alicuotaIva = 21,
    this.ambiente = AmbienteArca.homologacion,
    this.concepto = ConceptoFactura.ambos,
  });

  static const alicuotas = [21.0, 10.5, 27.0, 5.0, 2.5, 0.0];

  final String razonSocial;
  final String cuit;
  final CondicionIva condicionIva;
  final String domicilio;
  final String ingresosBrutos;
  final String inicioActividades;
  final int puntoVenta;
  final double alicuotaIva;
  final AmbienteArca ambiente;
  final ConceptoFactura concepto;

  bool get completa => razonSocial.isNotEmpty && cuit.length == 11 && puntoVenta > 0;

  factory ConfigFiscal.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const ConfigFiscal();
    return ConfigFiscal(
      razonSocial: leerTexto(m['razonSocial']),
      cuit: leerTexto(m['cuit']),
      condicionIva: CondicionIva.desde(m['condicionIva'] as String?, porDefecto: CondicionIva.monotributo),
      domicilio: leerTexto(m['domicilio']),
      ingresosBrutos: leerTexto(m['ingresosBrutos']),
      inicioActividades: leerTexto(m['inicioActividades']),
      puntoVenta: m['puntoVenta'] == null ? 1 : leerInt(m['puntoVenta']),
      alicuotaIva: m['alicuotaIva'] == null ? 21 : leerDouble(m['alicuotaIva']),
      ambiente: AmbienteArca.desde(m['ambiente'] as String?),
      concepto: ConceptoFactura.desde(m['concepto']),
    );
  }

  Map<String, dynamic> toMap() => {
        'razonSocial': razonSocial.trim(),
        'cuit': cuit.replaceAll(RegExp(r'\D'), ''),
        'condicionIva': condicionIva.valor,
        'domicilio': domicilio.trim(),
        'ingresosBrutos': ingresosBrutos.trim(),
        'inicioActividades': inicioActividades.trim(),
        'puntoVenta': puntoVenta,
        // Entero si no tiene decimales (las reglas comparan contra la lista).
        'alicuotaIva': alicuotaIva == alicuotaIva.roundToDouble() ? alicuotaIva.toInt() : alicuotaIva,
        'ambiente': ambiente.valor,
        'concepto': concepto.valor,
      };
}

/// Estado de la conexión con ARCA para un ambiente (lo escribe el servidor).
class EstadoArca {
  const EstadoArca({this.estado = 'sin_configurar', this.cuit = '', this.certificadoVence, this.mensaje, this.ultimaPrueba});

  final String estado;
  final String cuit;
  final DateTime? certificadoVence;
  final String? mensaje;
  final DateTime? ultimaPrueba;

  bool get listo => estado == 'listo';
  bool get esperandoCertificado => estado == 'esperando_certificado';

  factory EstadoArca.fromMap(Map<String, dynamic>? m) => m == null
      ? const EstadoArca()
      : EstadoArca(
          estado: leerTexto(m['estado']).isEmpty ? 'sin_configurar' : leerTexto(m['estado']),
          cuit: leerTexto(m['cuit']),
          certificadoVence: leerFecha(m['certificadoVence']),
          mensaje: leerTextoONull(m['mensaje']),
          ultimaPrueba: leerFecha(m['ultimaPrueba']),
        );
}

enum EstadoFactura {
  procesando('procesando', 'Procesando'),
  autorizada('autorizada', 'Autorizada'),
  rechazada('rechazada', 'Rechazada'),
  incierta('incierta', 'Sin confirmar');

  const EstadoFactura(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  static EstadoFactura desde(String? v) => values.firstWhere((e) => e.valor == v, orElse: () => procesando);
}

/// Comprobante electrónico (factura o nota de crédito) autorizado por ARCA.
class Factura {
  const Factura({
    required this.id,
    required this.estado,
    required this.tipo,
    required this.letra,
    required this.esNotaCredito,
    required this.puntoVenta,
    required this.numero,
    required this.emisor,
    required this.receptorNombre,
    required this.receptorDocTipo,
    required this.receptorDocNro,
    required this.receptorCondicion,
    required this.items,
    required this.total,
    required this.neto,
    required this.iva,
    required this.alicuota,
    required this.origenTipo,
    required this.origenId,
    required this.origenNumero,
    required this.ambiente,
    this.fecha,
    this.creado,
    this.cae,
    this.caeVence,
    this.qr,
    this.mensaje,
    this.notaCreditoId,
    this.anulada = false,
    this.asociada,
    this.concepto = ConceptoFactura.ambos,
  });

  final String id;
  final EstadoFactura estado;
  final int tipo;
  final String letra;
  final bool esNotaCredito;
  final int puntoVenta;
  final int? numero;
  final Map<String, dynamic> emisor;
  final String receptorNombre;
  final int receptorDocTipo;
  final int receptorDocNro;
  final CondicionIva receptorCondicion;
  final List<ItemLinea> items;
  final double total;
  final double neto;
  final double iva;
  final double? alicuota;
  final String origenTipo;
  final String origenId;
  final int? origenNumero;
  final AmbienteArca ambiente;
  final DateTime? fecha;
  final DateTime? creado;
  final String? cae;
  final DateTime? caeVence;
  final String? qr;
  final String? mensaje;
  final String? notaCreditoId;
  final bool anulada;
  final String? asociada;
  final ConceptoFactura concepto;

  String get nombreTipo => esNotaCredito ? 'Nota de crédito $letra' : 'Factura $letra';

  /// Código de comprobante (01 = Factura A, 06 = Factura B…).
  String get codigo => tipo.toString().padLeft(2, '0');

  String get numeroCompleto =>
      '${puntoVenta.toString().padLeft(5, '0')}-${numero == null ? '--------' : numero.toString().padLeft(8, '0')}';

  bool get discriminaIva => letra == 'A';

  String get documentoReceptor => switch (receptorDocTipo) {
        80 => 'CUIT $receptorDocNro',
        86 => 'CUIL $receptorDocNro',
        96 => 'DNI $receptorDocNro',
        _ => 'Consumidor final',
      };

  factory Factura.fromMap(String id, Map<String, dynamic> m) {
    final receptor = Map<String, dynamic>.from((m['receptor'] as Map?) ?? const {});
    final importes = Map<String, dynamic>.from((m['importes'] as Map?) ?? const {});
    final origen = Map<String, dynamic>.from((m['origen'] as Map?) ?? const {});
    final asoc = m['asociada'] as Map?;
    return Factura(
      id: id,
      estado: EstadoFactura.desde(m['estado'] as String?),
      tipo: leerInt(m['tipo']),
      letra: leerTexto(m['letra']),
      esNotaCredito: m['esNotaCredito'] == true,
      puntoVenta: leerInt(m['puntoVenta']),
      numero: m['numero'] == null ? null : leerInt(m['numero']),
      emisor: Map<String, dynamic>.from((m['emisor'] as Map?) ?? const {}),
      receptorNombre: leerTexto(receptor['nombre']),
      receptorDocTipo: leerInt(receptor['docTipo']),
      receptorDocNro: leerInt(receptor['docNro']),
      receptorCondicion: CondicionIva.desde(receptor['condicionIva'] as String?),
      items: ItemLinea.listaDesde(m['items']),
      total: leerDouble(importes['total']),
      neto: leerDouble(importes['neto']),
      iva: leerDouble(importes['iva']),
      alicuota: importes['alicuota'] == null ? null : leerDouble(importes['alicuota']),
      origenTipo: leerTexto(origen['tipo']),
      origenId: leerTexto(origen['id']),
      origenNumero: origen['numero'] == null ? null : leerInt(origen['numero']),
      ambiente: AmbienteArca.desde(m['ambiente'] as String?),
      fecha: leerFecha(m['fecha']),
      creado: leerFecha(m['creado']),
      cae: leerTextoONull(m['cae']),
      caeVence: leerFecha(m['caeVence']),
      qr: leerTextoONull(m['qr']),
      mensaje: leerTextoONull(m['mensaje']),
      notaCreditoId: leerTextoONull(m['notaCreditoId']),
      anulada: m['anulada'] == true,
      asociada: asoc == null
          ? null
          : '${asoc['letra'] ?? ''} ${leerInt(asoc['puntoVenta']).toString().padLeft(5, '0')}-${leerInt(asoc['numero']).toString().padLeft(8, '0')}',
      concepto: ConceptoFactura.desde(m['concepto']),
    );
  }
}

/// Datos de quien recibe la factura (los completa el usuario al facturar).
class ReceptorFactura {
  const ReceptorFactura({required this.nombre, required this.docTipo, this.docNro = '', required this.condicionIva});

  final String nombre;

  /// 'cuit', 'dni' o 'consumidor_final'.
  final String docTipo;
  final String docNro;
  final CondicionIva condicionIva;

  Map<String, dynamic> toMap() => {
        'nombre': nombre.trim(),
        'docTipo': docTipo,
        'docNro': docNro.replaceAll(RegExp(r'\D'), ''),
        'condicionIva': condicionIva.valor,
      };

  /// Letra que va a corresponder (para mostrarla antes de emitir).
  static String letraPara(CondicionIva emisor, CondicionIva receptor) {
    if (emisor != CondicionIva.responsableInscripto) return 'C';
    return (receptor == CondicionIva.responsableInscripto || receptor == CondicionIva.monotributo) ? 'A' : 'B';
  }
}

/// Valida un CUIT/CUIL con su dígito verificador (misma lógica que el servidor).
bool cuitValido(String cuit) {
  final d = cuit.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return false;
  const pesos = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  var suma = 0;
  for (var i = 0; i < 10; i++) {
    suma += pesos[i] * int.parse(d[i]);
  }
  var v = 11 - (suma % 11);
  if (v == 11) v = 0;
  if (v == 10) return false;
  return v == int.parse(d[10]);
}
