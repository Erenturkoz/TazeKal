/// Lower-cases Turkish text, folds diacritics to ASCII and replaces every
/// other character with a space so product names can be keyword-matched.
String normalizeTurkish(String value) => value
    .replaceAll('I', 'ı')
    .replaceAll('İ', 'i')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ç', 'c')
    .replaceAll('ğ', 'g')
    .replaceAll('â', 'a')
    .replaceAll('î', 'i')
    .replaceAll('û', 'u')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
