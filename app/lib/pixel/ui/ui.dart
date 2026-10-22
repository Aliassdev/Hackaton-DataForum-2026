/// Kit de interfaz pixel de Vive el caso: el juego es un mundo de 8 bits dentro de la app, y no solo los personajes
/// y los lugares, también los botones, las barras, los tickets, las cartas y la letra.
///
/// - [BotonPixel]: primario, secundario y de peligro; con icono, pulsado y desactivado.
/// - [BarraPixel]: barra de progreso por segmentos, como la vida de un juego.
/// - [DialogoPixel] y [ControladorDialogoPixel]: ventana de diálogo con el texto letra a letra.
/// - [MenuOpcionesPixel]: opciones con cursor ► y la respuesta correcta o incorrecta.
/// - [TicketPixel] y [CartaPixel]: el ticket de turno y las cartas de derecho.
/// - [MarcoPixel] y [HudPixel]: el marco de la pantalla de juego y su barra de arriba.
/// - [RotuloPixel]: números y códigos («2/5», «N.º 3», «A-07») con letra pixel propia, sin cifras que se confundan.
/// - [transicionPixel], [PaginaPixel] y [paginaPixel]: la transición a bloques para entrar en el juego.
/// - [GaleriaPixelUi]: todo junto, para revisarlo.
///
/// Debajo: [TemaPixel] y [familiaPixel] (la letra, en un solo sitio), [FondoPixel] (lo que hay detrás: sobre azul
/// noche, las piezas llevan filo), [ScrollPixel], [estiloTextoPixel], [unidadPixel] (el tamaño de un pixel del
/// juego), [ColoresUiPixel], [CajaPixel], [AjustePixel] (nitidez con Impeller) e [IconoPixel].
///
/// Todo respeta «reducir animaciones» y se puede usar con lector de pantalla, con teclado y con letra grande.
library;

export 'barra_pixel.dart';
export 'boton_pixel.dart';
export 'carta_pixel.dart';
export 'dialogo_pixel.dart';
export 'estilo_pixel.dart';
export 'galeria_pixel_ui.dart';
export 'hud_pixel.dart';
export 'iconos_pixel.dart';
export 'marco_pixel.dart';
export 'menu_opciones_pixel.dart';
export 'pintura_pixel.dart' show AjustePixel, CajaPixel, EstiloCajaPixel, PintorCajaPixel, RenderAjustePixel;
export 'rotulo_pixel.dart';
export 'ticket_pixel.dart';
export 'transicion_pixel.dart';
