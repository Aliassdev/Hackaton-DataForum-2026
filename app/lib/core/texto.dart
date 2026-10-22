const _conTilde = 'áàäâéèëêíìïîóòöôúùüûñç';
const _sinTilde = 'aaaaeeeeiiiioooouuuunc';

/// Minúsculas y sin tildes, para buscar y ordenar sin que importen.
String normalizar(String texto) {
  final resultado = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    // Tilde suelta de un texto descompuesto (NFD), p. ej. «i» + «◌́»: se quita como las demás.
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    final caracter = String.fromCharCode(rune);
    final i = _conTilde.indexOf(caracter);
    resultado.write(i >= 0 ? _sinTilde[i] : caracter);
  }
  return resultado.toString();
}
