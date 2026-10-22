// Detecta si la página se abre en un Android o en un iPhone/iPad, pone primero su opción y la destaca. estilo.css
// esconde la otra con data-plataforma: en Android, «Probar ya» ya está en su tarjeta, y en iPhone o iPad no se puede
// instalar la APK. En el ordenador ('otro') se ven las dos y el QR. Sin JavaScript se ven las dos con el mismo peso.
// No guarda nada ni lo envía a ningún sitio.
(function () {
  'use strict';

  var ua = navigator.userAgent || '';
  var datos = navigator.userAgentData;
  var esAndroid = /Android/i.test(ua) || Boolean(datos && datos.platform === 'Android');
  // Los iPad con iPadOS 13 o más se presentan como un Mac: se distinguen porque tienen pantalla táctil.
  var esIOS = /iPhone|iPad|iPod/i.test(ua) || (/Macintosh/i.test(ua) && navigator.maxTouchPoints > 1);
  var plataforma = esAndroid ? 'android' : esIOS ? 'ios' : 'otro';
  document.documentElement.setAttribute('data-plataforma', plataforma);
  if (plataforma === 'otro') return;

  var recomendada = document.getElementById(plataforma === 'android' ? 'opcion-android' : 'opcion-web');
  var otra = document.getElementById(plataforma === 'android' ? 'opcion-web' : 'opcion-android');
  if (!recomendada || !otra) return;

  // La recomendada va primero también en el orden de lectura y del teclado, no solo a la vista.
  if (otra.compareDocumentPosition(recomendada) & Node.DOCUMENT_POSITION_FOLLOWING) {
    otra.parentNode.insertBefore(recomendada, otra);
  }
  recomendada.classList.add('opcion--recomendada');
  var etiqueta = recomendada.querySelector('.recomendada');
  if (etiqueta) etiqueta.hidden = false;
})();
