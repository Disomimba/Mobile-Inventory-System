import 'package:flutter/material.dart';

enum ElementType { door, rack, shelf, cashier, pathway }

class MapElement {
  final String id;
  final ElementType type;
  Offset position;
  Size size;
  final String label;
  double rotation;

  MapElement({
    required this.id,
    required this.type,
    required this.position,
    this.size = const Size(100, 100),
    this.label = "",
    this.rotation = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'dx': position.dx,
    'dy': position.dy,
    'width': size.width,
    'height': size.height,
    'label': label,
    'rotation': rotation,
  };

  factory MapElement.fromJson(Map<String, dynamic> json) => MapElement(
    id: json['id'],
    type: ElementType.values[json['type'] ?? 0],
    position: Offset(
      (json['dx'] ?? 0.0).toDouble(),
      (json['dy'] ?? 0.0).toDouble(),
    ),
    size: Size(
      (json['width'] ?? 100.0).toDouble(),
      (json['height'] ?? 100.0).toDouble(),
    ),
    label: json['label'] ?? "",
    rotation: (json['rotation'] ?? 0.0).toDouble(),
  );
}

class ItemLocation {
  final String aisle;
  final int shelf;
  final String section;

  ItemLocation({
    required this.aisle,
    required this.shelf,
    required this.section,
  });
}

class InventoryItem {
  final String id;
  final String name;
  final String sku;
  final double price;
  double quantity;
  final double maxQuantity; // ADDED MAX QUANTITY
  final String category;
  final String description;
  final String imageUrl;
  final ItemLocation? location;
  final String? locationId;
  final String? manufacturer;
  final String? model;
  final String? productSize;
  final String? shelfLevel;
  final String? binNumber;
  final String unit;

  InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.quantity,
    required this.maxQuantity, // ADDED MAX QUANTITY
    required this.category,
    required this.description,
    required this.imageUrl,
    this.location,
    this.locationId,
    this.manufacturer,
    this.model,
    this.productSize,
    this.shelfLevel,
    this.binNumber,
    this.unit = 'pcs',
  });

  factory InventoryItem.fromSupabase(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'].toString(),
      sku: map['sku'] ?? '',
      name: map['product_name'] ?? 'Unknown Item',
      category: map['category'] ?? 'General',
      price: (map['product_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['product_quantity'] as num?)?.toDouble() ?? 0.0,
      maxQuantity:
          (map['max_quantity'] as num?)?.toDouble() ??
          100.0, // READ FROM DB WITH FALLBACK
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      locationId: map['map_element_id'],
      manufacturer: map['manufacturer'],
      model: map['model'],
      productSize: map['product_size'],
      shelfLevel: map['shelf_level'],
      binNumber: map['bin_number'],
      unit: map['unit'] ?? 'pcs',
    );
  }

  InventoryItem copyWith({
    String? name,
    String? sku,
    double? price,
    double? quantity,
    double? maxQuantity, // ADDED MAX QUANTITY
    String? category,
    String? description,
    String? imageUrl,
    String? locationId,
    String? manufacturer,
    String? model,
    String? productSize,
    String? shelfLevel,
    String? binNumber,
    String? unit,
  }) {
    return InventoryItem(
      id: this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      maxQuantity: maxQuantity ?? this.maxQuantity, // ADDED MAX QUANTITY
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      locationId: locationId ?? this.locationId,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      productSize: productSize ?? this.productSize,
      shelfLevel: shelfLevel ?? this.shelfLevel,
      binNumber: binNumber ?? this.binNumber,
      unit: unit ?? this.unit,
    );
  }
}

class CustomerOrderItem {
  final String productId;
  final String productName;
  final double quantity;

  CustomerOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
  };

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) =>
      CustomerOrderItem(
        productId: json['product_id'],
        productName: json['product_name'],
        quantity: (json['quantity'] as num).toDouble(),
      );
}

class CustomerOrder {
  final String id;
  final String status;
  final DateTime createdAt;
  final List<CustomerOrderItem> items;

  CustomerOrder({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory CustomerOrder.fromSupabase(Map<String, dynamic> map) {
    var itemsList = <CustomerOrderItem>[];
    if (map['items'] != null) {
      itemsList = (map['items'] as List)
          .map((i) => CustomerOrderItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    return CustomerOrder(
      id: map['id'].toString(),
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      items: itemsList,
    );
  }
}
