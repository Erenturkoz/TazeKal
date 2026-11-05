import 'opening_profile.dart';

DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime addCalendarDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);
String dateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String displayDate(DateTime? value) => value == null
    ? 'Tarih belirtilmedi'
    : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

int calendarDifference(DateTime to, DateTime from) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String relativeDay(DateTime value, DateTime now) {
  final days = calendarDifference(now, value);
  return days == 0
      ? 'Bugün'
      : days == 1
      ? 'Dün'
      : '$days gün önce';
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.quantity,
    required this.location,
    required this.purchasedAt,
    this.expiresAt,
    this.expirySource,
    this.shelfLifeProfileId,
    this.openedAt,
    this.afterOpeningDays,
    this.openingProfileId,
    this.coldStorageConfirmed = false,
    this.localRevision,
    this.localOwnerId,
    this.status = 'active',
  });
  final String id, name, quantity, location, status;
  final DateTime purchasedAt;
  final DateTime? expiresAt;
  final String? expirySource, shelfLifeProfileId;
  bool get usesPurchaseEstimate => expirySource == 'estimated';
  bool get usesEstimate => usesPurchaseEstimate || usesOpeningEstimate;
  bool isPast(DateTime now) =>
      effectiveExpiry != null && calendarDifference(effectiveExpiry!, now) < 0;
  bool isArchived(DateTime now) => status == 'consumed' || isPast(now);
  final DateTime? openedAt;
  final int? afterOpeningDays;
  final String? openingProfileId;
  final bool coldStorageConfirmed;
  // Local concurrency/ownership metadata is deliberately excluded from toMap().
  final int? localRevision;
  final String? localOwnerId;

  OpeningProfile? get openingProfile => OpeningProfile.find(openingProfileId);
  bool get openingConditionsMet =>
      location == 'Buzdolabı' && coldStorageConfirmed;
  int? get openingDays {
    // Existing label instructions remain valid for products without a profile.
    if (openingProfileId != null && !openingConditionsMet) return null;
    final labelDays = afterOpeningDays;
    if (labelDays != null && labelDays > 0) return labelDays;
    return openingConditionsMet ? openingProfile?.days : null;
  }

  bool get hasTrackingDate =>
      effectiveExpiry != null && (openedAt == null || openingDays != null);
  bool get usesOpeningEstimate =>
      openedAt != null && afterOpeningDays == null && openingDays != null;
  DateTime? get openingExpiry => openedAt == null || openingDays == null
      ? null
      : addCalendarDays(openedAt!, openingDays!);
  int? unopenedDaysLeft(DateTime now) =>
      expiresAt == null ? null : calendarDifference(expiresAt!, now);
  String remainingText(DateTime now) {
    if (!hasTrackingDate) {
      if (expiresAt == null && openedAt == null) {
        return 'Tarih yok • stokta takip ediliyor';
      }
      return (unopenedDaysLeft(now) ?? 0) < 0
          ? 'Ambalaj tarihi geçti; açılma süresi hesaplanamıyor'
          : 'Açılma süresi henüz hesaplanamıyor';
    }
    final n = daysLeft(now);
    final prefix = usesEstimate ? 'Tahmini ' : '';
    if (n < 0) return '${prefix}tüketim süresi geçti';
    if (n == 0) return '${prefix}tüketim süresinin son günü';
    return '$prefix$n gün kaldı';
  }

  DateTime? get effectiveExpiry {
    final opened = openedAt;
    final days = openingDays;
    final expiry = expiresAt;
    if (opened == null || days == null) {
      return expiry == null ? null : calendarDay(expiry);
    }
    final after = addCalendarDays(opened, days);
    return expiry == null || after.isBefore(expiry)
        ? after
        : calendarDay(expiry);
  }

  int daysLeft(DateTime now) {
    return calendarDifference(effectiveExpiry!, now);
  }

  Product copyWith({
    DateTime? openedAt,
    String? status,
    String? name,
    String? quantity,
  }) => Product(
    id: id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    location: location,
    purchasedAt: purchasedAt,
    expiresAt: expiresAt,
    expirySource: expirySource,
    shelfLifeProfileId: shelfLifeProfileId,
    openedAt: openedAt ?? this.openedAt,
    afterOpeningDays: afterOpeningDays,
    openingProfileId: openingProfileId,
    coldStorageConfirmed: coldStorageConfirmed,
    localRevision: localRevision,
    localOwnerId: localOwnerId,
    status: status ?? this.status,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'location': location,
    'purchased_at': dateKey(purchasedAt),
    'expires_at': expiresAt == null ? null : dateKey(expiresAt!),
    if (expirySource != null) 'expiry_source': expirySource,
    if (shelfLifeProfileId != null) 'shelf_life_profile_id': shelfLifeProfileId,
    'opened_at': openedAt == null ? null : dateKey(openedAt!),
    'after_opening_days': afterOpeningDays,
    'opening_profile_id': openingProfileId,
    'cold_storage_confirmed': coldStorageConfirmed ? 1 : 0,
    'status': status,
  };

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id'] as String,
    name: map['name'] as String,
    quantity: map['quantity'] as String,
    location: map['location'] as String,
    purchasedAt: DateTime.parse(map['purchased_at'] as String),
    expiresAt: map['expires_at'] == null
        ? null
        : DateTime.parse(map['expires_at'] as String),
    expirySource: map['expiry_source'] as String?,
    shelfLifeProfileId: map['shelf_life_profile_id'] as String?,
    openedAt: map['opened_at'] == null
        ? null
        : DateTime.parse(map['opened_at'] as String),
    afterOpeningDays: map['after_opening_days'] as int?,
    openingProfileId: map['opening_profile_id'] as String?,
    coldStorageConfirmed: map['cold_storage_confirmed'] == 1,
    localRevision: map['local_revision'] as int?,
    localOwnerId: map['owner_id'] as String?,
    status: map['status'] as String,
  );
}
