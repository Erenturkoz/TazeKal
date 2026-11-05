import '../domain/product.dart';

class RemoteProduct {
  const RemoteProduct({
    required this.id,
    required this.version,
    required this.cursor,
    required this.deleted,
    this.product,
  });
  final String id;
  final int version, cursor;
  final bool deleted;
  final Product? product;
  factory RemoteProduct.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String,
        version = json['version'] as int,
        cursor = json['cursor'] as int;
    final deleted = json['deleted'] as bool;
    final product = deleted
        ? null
        : Product.fromMap(Map<String, Object?>.from(json['product'] as Map));
    if (version < 1 || cursor < 1 || (!deleted && product?.id != id)) {
      throw const FormatException('Invalid remote product');
    }
    return RemoteProduct(
      id: id,
      version: version,
      cursor: cursor,
      deleted: deleted,
      product: product,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'cursor': cursor,
    'deleted': deleted,
    'product': product?.toMap(),
  };
}

class PendingProduct {
  const PendingProduct({
    required this.mutationId,
    required this.productId,
    required this.revision,
    required this.baseVersion,
    required this.deleted,
    this.product,
  });
  final String mutationId, productId;
  final int revision, baseVersion;
  final bool deleted;
  final Product? product;
  Map<String, dynamic> toJson() => {
    'mutationId': mutationId,
    'productId': productId,
    'baseVersion': baseVersion,
    'deleted': deleted,
    'product': deleted ? null : product!.toMap(),
  };
}

class ProductConflict {
  const ProductConflict({
    required this.id,
    required this.local,
    required this.localDeleted,
    required this.localRevision,
    required this.remote,
  });
  final String id;
  final Product local;
  final bool localDeleted;
  final int localRevision;
  final RemoteProduct? remote;
}
