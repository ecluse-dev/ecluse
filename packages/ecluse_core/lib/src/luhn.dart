/// Algorithme de Luhn standard (mod 10) — utilisé par le RPPS et le FINESS
/// (et, par collision structurelle documentée, par le SIREN — voir
/// `FinessDetector`). Source unique : ne pas dupliquer ailleurs.
///
/// En partant de la droite, double un chiffre sur deux (en retranchant 9 si
/// le résultat dépasse 9) ; la somme totale doit être un multiple de 10.
bool isLuhnValid(String digits) {
  var sum = 0;
  var double = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var d = digits.codeUnitAt(i) - 0x30;
    if (double) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    double = !double;
  }
  return sum % 10 == 0;
}
