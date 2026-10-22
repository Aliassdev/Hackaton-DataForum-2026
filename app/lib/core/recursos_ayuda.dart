import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Un recurso del botón de Ayuda (sección 4.5). Lo usan la pantalla de Ayuda y la tarjeta de crisis.
///
/// Los datos están comprobados en docs/MARCO_LEGAL.md y siguen docs/ARQUITECTURA.md, secciones 2.3 y 4.5.
class RecursoAyuda {
  const RecursoAyuda({
    required this.nombre,
    required this.descripcion,
    required this.icono,
    this.telefono,
    this.web,
    this.chat,
    this.whatsapp,
    this.horario,
    this.notas = const [],
    this.urgente = false,
  });

  final String nombre;
  final String descripcion;
  final IconData icono;

  /// Tal como se lee, p. ej. «900 20 20 10».
  final String? telefono;
  final String? web;

  /// Chat para escribir en vez de llamar (por ejemplo, si no puedes hablar sin que te oigan).
  final String? chat;

  /// Número de WhatsApp tal como se lee, p. ej. «900 116 117». Otra forma de escribir en vez de llamar.
  final String? whatsapp;

  /// Solo en los recursos que no atienden a cualquier hora (el 017). Donde se enseñe el recurso, hay que
  /// enseñar también el horario.
  final Horario? horario;

  /// Aclaraciones cortas: para qué sirve, para qué no y desde qué edad.
  final List<NotaRecurso> notas;

  /// Para peligro inmediato (112).
  final bool urgente;

  Uri get uri => telefono != null ? Uri(scheme: 'tel', path: telefono!.replaceAll(' ', '')) : Uri.parse(web!);

  Uri? get uriChat => chat == null ? null : Uri.parse(chat!);

  /// La conversación de WhatsApp con ese número de España (como enlaza la propia web del INCIBE).
  Uri? get uriWhatsapp => whatsapp == null ? null : Uri.https('wa.me', '/34${whatsapp!.replaceAll(' ', '')}');

  /// El teléfono con espacios que no se cortan: en pantalla nunca se parte en dos líneas.
  String? get telefonoVisible => telefono?.replaceAll(' ', ' ');

  /// La web sin «https://» ni «www.», para enseñarla y poder escribirla a mano.
  String? get webVisible => web?.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
}

/// Horario de atención en hora peninsular española, la de los servicios estatales como el 017.
@immutable
class Horario {
  const Horario({required this.apertura, required this.cierre, required this.texto});

  /// Desde la medianoche.
  final Duration apertura;
  final Duration cierre;

  /// Como se enseña, p. ej. «Todos los días, de 8:00 a 23:00».
  final String texto;

  /// Si atiende en [momento]. Da igual la zona horaria del móvil: se pasa a hora peninsular.
  bool abierto(DateTime momento) {
    final hora = horaPeninsular(momento);
    final desdeMedianoche = Duration(hours: hora.hour, minutes: hora.minute);
    return desdeMedianoche >= apertura && desdeMedianoche < cierre;
  }

  /// La hora de apertura como se lee, p. ej. «8:00».
  String get textoApertura => '${apertura.inHours}:${(apertura.inMinutes % 60).toString().padLeft(2, '0')}';
}

/// La hora de Madrid en [momento]: UTC+1 en invierno y UTC+2 en verano (en la Unión Europea, del último domingo de
/// marzo al último domingo de octubre, con el cambio a la 1:00 UTC). Así el horario sale bien aunque el móvil esté en
/// otra zona, por ejemplo en Canarias. Solo valen la fecha y la hora del resultado, no su zona.
DateTime horaPeninsular(DateTime momento) {
  final utc = momento.toUtc();
  final verano =
      !utc.isBefore(_cambioDeHora(utc.year, DateTime.march)) && utc.isBefore(_cambioDeHora(utc.year, DateTime.october));
  return utc.add(Duration(hours: verano ? 2 : 1));
}

/// El último domingo de [mes], a la 1:00 UTC.
DateTime _cambioDeHora(int anio, int mes) {
  final ultimoDia = DateTime.utc(anio, mes + 1, 0, 1);
  return ultimoDia.subtract(Duration(days: ultimoDia.weekday % DateTime.daysPerWeek));
}

/// Qué indica una nota: algo para lo que sí sirve, algo para lo que no sirve o un dato útil.
enum TipoNota { sirve, noSirve, info }

/// Aclaración corta de un recurso. El texto se entiende solo, sin el icono.
@immutable
class NotaRecurso {
  const NotaRecurso(this.texto, {this.tipo = TipoNota.info});

  final String texto;
  final TipoNota tipo;
}

const mensajeAdultoDeConfianza = 'Habla con un adulto de confianza o con el coordinador de bienestar de tu centro.';

const recursosAyuda = <RecursoAyuda>[
  RecursoAyuda(
    nombre: 'Fundación ANAR',
    telefono: '900 20 20 10',
    descripcion: 'Para chicos, chicas y adolescentes. Gratis, confidencial y a cualquier hora. También por chat.',
    icono: Icons.support_agent_rounded,
    // Enlace al chat que publica la propia fundación en www.anar.org.
    chat: 'https://chatanar.es',
  ),
  // ANAR atiende el 116 111 en muchas comunidades, no en todas (lo dice su propia web, www.anar.org): en el resto
  // lo atiende otro servicio. El 900 20 20 10 de ANAR sí sirve desde toda España.
  RecursoAyuda(
    nombre: 'Línea de ayuda a la infancia',
    telefono: '116 111',
    descripcion: 'Teléfono europeo de ayuda a la infancia. En muchas comunidades lo atiende ANAR.',
    icono: Icons.child_care_rounded,
  ),
  RecursoAyuda(
    nombre: 'Emergencias',
    telefono: '112',
    descripcion: 'Si estás en peligro ahora mismo.',
    icono: Icons.emergency_rounded,
    urgente: true,
  ),
  // INCIBE: «todos los días de 8:00 a 23:00», no 24 horas. También por WhatsApp (docs/MARCO_LEGAL.md).
  RecursoAyuda(
    nombre: 'Ciberseguridad (INCIBE)',
    telefono: '017',
    whatsapp: '900 116 117',
    horario: Horario(
      apertura: Duration(hours: 8),
      cierre: Duration(hours: 23),
      texto: 'Todos los días, de 8:00 a 23:00',
    ),
    descripcion: 'Si tienes un problema en internet: acoso, fotos, cuentas robadas… Es gratis y confidencial.',
    icono: Icons.security_rounded,
  ),
  RecursoAyuda(
    nombre: 'Violencia de género',
    telefono: '016',
    descripcion: 'Información y ayuda ante la violencia de género.',
    icono: Icons.favorite_rounded,
  ),
  RecursoAyuda(
    nombre: 'Canal Joven de la AEPD',
    telefono: '900 293 183',
    descripcion:
        'De la Agencia Española de Protección de Datos (AEPD). Para dudas o problemas con tu privacidad y tus datos '
        'personales.',
    icono: Icons.privacy_tip_rounded,
  ),
  // AEPD, Canal prioritario y FAQ 15.03; LOPIVI, art. 52 (docs/MARCO_LEGAL.md y ARQUITECTURA.md, 2.3).
  RecursoAyuda(
    nombre: 'Quitar fotos o vídeos de internet',
    web: 'https://www.aepd.es/canalprioritario',
    descripcion:
        'Es el Canal prioritario de la AEPD. Pide que quiten enseguida fotos, vídeos o audios sexuales o violentos '
        'publicados sin permiso, tuyos o de otra persona.',
    notas: [
      NotaRecurso('Sirve para redes sociales y webs.', tipo: TipoNota.sirve),
      NotaRecurso(
        'No sirve para WhatsApp, Telegram ni el correo. En ese caso, puedes ir a la policía o a la Fiscalía.',
        tipo: TipoNota.noSirve,
      ),
      NotaRecurso(
        'Desde los 14 años puedes pedirlo tú, sin un adulto. Con menos de 14, que lo haga un adulto de confianza.',
      ),
    ],
    icono: Icons.no_photography_rounded,
  ),
];

/// Abre el marcador con el número (no llama solo) o el navegador. Devuelve false si no se pudo.
Future<bool> abrirRecurso(RecursoAyuda recurso) => _abrir(recurso.uri);

/// Abre el chat del recurso en el navegador. Devuelve false si no tiene chat o no se pudo.
Future<bool> abrirChat(RecursoAyuda recurso) async {
  final uri = recurso.uriChat;
  return uri != null && await _abrir(uri);
}

/// Abre WhatsApp (o su web, si no está instalado) con el número del recurso. Devuelve false si no tiene o no se pudo.
Future<bool> abrirWhatsapp(RecursoAyuda recurso) async {
  final uri = recurso.uriWhatsapp;
  return uri != null && await _abrir(uri);
}

Future<bool> _abrir(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
