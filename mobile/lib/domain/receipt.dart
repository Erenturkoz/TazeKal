/// Conservative receipt suggestions, never inventory records or expiry guesses.
class ReceiptItem {
  const ReceiptItem(this.name, {this.quantity = '1 adet'});
  final String name, quantity;
}

List<ReceiptItem> parseReceipt(String text) {
  final result = <ReceiptItem>[];
  final metadata = RegExp(
    r'^(TOPLAM|ARA TOPLAM|GENEL TOPLAM|KDV|TOPKDV|NAK[Iİ]T|KRED[Iİ]|BANKA|POS|ÖDEME|ODEME|PARA ÜSTÜ|PARA USTU|F[Iİ][ŞS]|TAR[Iİ]H|SAAT|VERG[Iİ]|VKN|MERS[Iİ]S|TEL|ADRES|KAS[Iİ]YER|KASA|TE[ŞS]EKK\S*|HO[ŞS] GELD\S*|MÜ[ŞS]TER[Iİ]|MUSTER[Iİ]|[İI]ND[İI]R[İI]M|[İI]SKONTO|PUAN)(\s|:|$)',
    caseSensitive: false,
    unicode: true,
  );
  for (final raw in text.split(RegExp(r'[\r\n]+'))) {
    var line = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (line.isEmpty || metadata.hasMatch(line)) continue;
    // Skip timestamp, phone, tax and standalone quantity/price lines.
    if (!RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜ]').hasMatch(line)) {
      continue;
    }
    line = line.replaceFirst(
      RegExp(
        r'\s+[%*]?\d{1,2}\s+[*]?\d+[.,]\d{2}\s*(TL|₺)?$',
        caseSensitive: false,
      ),
      '',
    );
    line = line.replaceFirst(
      RegExp(r'\s+[*]?\d+[.,]\d{2}\s*(TL|₺)?$', caseSensitive: false),
      '',
    );
    final count = RegExp(r'^(\d+)\s*[xX*]\s*').firstMatch(line);
    var quantity = '1 adet';
    if (count != null) {
      quantity = '${count.group(1)} adet';
      line = line.substring(count.end).trim();
    }
    if (!RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜ]').hasMatch(line)) continue;
    if (line.length >= 2 && line.length <= 100) {
      result.add(ReceiptItem(line, quantity: quantity));
    }
  }
  return result;
}
