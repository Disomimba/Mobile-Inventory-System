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
    position: Offset((json['dx'] ?? 0.0).toDouble(), (json['dy'] ?? 0.0).toDouble()),
    size: Size((json['width'] ?? 100.0).toDouble(), (json['height'] ?? 100.0).toDouble()),
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
  final int quantity;
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

  InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.quantity,
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
  });

  factory InventoryItem.fromSupabase(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'].toString(),
      sku: map['sku'] ?? '',
      name: map['product_name'] ?? 'Unknown Item',
      category: map['category'] ?? 'General',
      price: (map['product_price'] as num?)?.toDouble() ?? 0.0,
      quantity: map['product_quantity'] as int? ?? 0,
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      locationId: map['map_element_id'],
      manufacturer: map['manufacturer'],
      model: map['model'],
      productSize: map['product_size'],
      shelfLevel: map['shelf_level'],
      binNumber: map['bin_number'],
    );
  }

  InventoryItem copyWith({
    String? name,
    String? sku,
    double? price,
    int? quantity,
    String? description,
    String? imageUrl,
    String? locationId,
    String? manufacturer,
    String? model,
    String? productSize,
    String? shelfLevel,
    String? binNumber,
  }) {
    return InventoryItem(
      id: this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      locationId: locationId ?? this.locationId,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      productSize: productSize ?? this.productSize,
      shelfLevel: shelfLevel ?? this.shelfLevel,
      binNumber: binNumber ?? this.binNumber,
    );
  }
}