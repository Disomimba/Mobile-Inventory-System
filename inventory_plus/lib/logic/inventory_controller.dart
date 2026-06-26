import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import '../data/inventory.dart';

class InventoryController {
  final SupabaseClient supabase = Supabase.instance.client;
  int? currentUserNumericId;
  List<MapElement> storeLayout = [];
  List<InventoryItem> _items = [];
  String? activeLocationId;
  String? currentUserRole;
  String? currentUserName;
  String? currentUserId;
  String? loggedInUserEmail;
  bool get isAdmin => currentUserRole?.toLowerCase() == 'admin';

  List<InventoryItem> get allItems => _items;

  void setLoggedInUser({
    required String name,
    required String id,
    required String role,
    String? email,
  }) {
    currentUserName = name;
    currentUserId = id;
    currentUserRole = role;
    currentUserNumericId = int.tryParse(id);
    loggedInUserEmail = email;
  }

  // Helper method to hash the password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> loadAppData(String userLocationId) async {
    activeLocationId = userLocationId;

    try {
      final productsResponse = await supabase
          .from('products')
          .select()
          .eq('location_id', userLocationId);

      final locationResponse = await supabase
          .from('locations')
          .select('layout_data')
          .eq('id', userLocationId)
          .single();

      _items = (productsResponse as List)
          .map((p) => InventoryItem.fromSupabase(p))
          .toList();

      if (locationResponse['layout_data'] != null) {
        final List<dynamic> layoutJson = locationResponse['layout_data'];
        storeLayout = layoutJson.map((el) => MapElement.fromJson(el)).toList();
      }
    } catch (e) {
      _items = [];
      storeLayout = [];
    }
  }

  Future<void> saveLayout() async {
    final locId = activeLocationId;
    if (locId == null) return;

    try {
      final String encodedData = jsonEncode(
        storeLayout.map((el) => el.toJson()).toList(),
      );

      await supabase
          .from('locations')
          .update({'layout_data': jsonDecode(encodedData)})
          .eq('id', locId);
    } catch (e) {}
  }

  Future<void> addItem(InventoryItem newItem) async {
    final locId = activeLocationId;
    if (locId == null) {
      return;
    }

    try {
      final response = await supabase
          .from('products')
          .insert({
            'sku': newItem.sku,
            'product_name': newItem.name,
            'category': newItem.category,
            'product_price': newItem.price,
            'product_quantity': newItem.quantity,
            'description': newItem.description,
            'image_url': newItem.imageUrl,
            'location_id': locId,
            'map_element_id': newItem.locationId,
            'manufacturer': newItem.manufacturer,
            'model': newItem.model,
            'product_size': newItem.productSize,
            'shelf_level': newItem.shelfLevel,
            'bin_number': newItem.binNumber,
            'unit': newItem.unit,
            'max_quantity': newItem.maxQuantity,
          })
          .select()
          .single();

      final savedItem = InventoryItem.fromSupabase(response);

      _items.add(savedItem);

      await _logTransaction(
        productId: savedItem.id,
        type: 'add',
        quantityChange: savedItem.quantity,
        newQuantity: savedItem.quantity,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _logTransaction({
    String? productId,
    required String type,
    required double quantityChange,
    required double newQuantity,
  }) async {
    final locId = activeLocationId;
    final userId = currentUserId;
    final userName = currentUserName ?? 'Unknown User';

    if (locId == null || userId == null) return;
    try {
      final Map<String, dynamic> insertData = {
        'product_id': productId,
        'transaction_type': type,
        'quantity_change': quantityChange,
        'new_quantity': newQuantity,
        'location_id': locId,
        'user_id': int.tryParse(userId) ?? userId,
        'user_name': userName,
      };

      await supabase.from('transaction_history').insert(insertData);
    } catch (e) {}
  }

  // Uploads an image to Supabase Storage and returns the public URL
  Future<String?> uploadProductImage(File imageFile, String fileName) async {
    try {
      // Generate a unique path to prevent overwriting images with the same name
      final path = 'public/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await supabase.storage.from('product_images').upload(path, imageFile);

      final imageUrl = supabase.storage
          .from('product_images')
          .getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      return null;
    }
  }

  // Uploads an image from bytes (Required for Flutter Web)
  Future<String?> uploadImageBytes(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final path = 'public/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await supabase.storage
          .from('product_images')
          .uploadBinary(path, imageBytes);

      final imageUrl = supabase.storage
          .from('product_images')
          .getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateItem(InventoryItem updatedItem) async {
    try {
      final index = _items.indexWhere((item) => item.id == updatedItem.id);
      if (index != -1) {
        final oldItem = _items[index];
        final quantityChange = updatedItem.quantity - oldItem.quantity;

        // Optimistically update local state immediately
        _items[index] = updatedItem;

        if (quantityChange != 0) {
          await _logTransaction(
            productId: updatedItem.id,
            type: quantityChange > 0 ? 'stock_in' : 'checkout',
            quantityChange: quantityChange,
            newQuantity: updatedItem.quantity,
          );
        }
      }

      await supabase
          .from('products')
          .update({
            'product_name': updatedItem.name,
            'sku': updatedItem.sku,
            'product_price': updatedItem.price,
            'product_quantity': updatedItem.quantity,
            'description': updatedItem.description,
            'manufacturer': updatedItem.manufacturer,
            'model': updatedItem.model,
            'product_size': updatedItem.productSize,
            'shelf_level': updatedItem.shelfLevel,
            'bin_number': updatedItem.binNumber,
            'image_url': updatedItem.imageUrl,
            'map_element_id': updatedItem.locationId,
            'unit': updatedItem.unit,
            'max_quantity': updatedItem.maxQuantity,
          })
          .eq('id', updatedItem.id);
    } catch (e) {}
  }

  Future<void> deleteItem(String id) async {
    try {
      final index = _items.indexWhere((item) => item.id == id);
      await supabase.from('products').delete().eq('id', id);

      if (index != -1) {
        final itemToDelete = _items[index];
        _items.removeAt(index);
        await _logTransaction(
          productId:
              null, // Null to prevent Foreign Key constraint error on cascade delete
          type: 'delete',
          quantityChange: -itemToDelete.quantity,
          newQuantity: 0,
        );
      }
    } catch (e) {}
  }

  Future<void> assignItemToLocation(String itemId, String? rackId) async {
    try {
      await supabase
          .from('products')
          .update({'map_element_id': rackId})
          .eq('id', itemId);

      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        final current = _items[index];
        // FIXED: Using copyWith to safely preserve maxQuantity, unit, and all other fields
        _items[index] = current.copyWith(locationId: rackId);
      }
    } catch (e) {}
  }

  Future<void> deleteMapElement(String elementId) async {
    try {
      storeLayout.removeWhere((item) => item.id == elementId);

      // Unassign all items that were assigned to this element
      final itemsToUnassign = _items
          .where((item) => item.locationId == elementId)
          .toList();
      for (var item in itemsToUnassign) {
        await assignItemToLocation(item.id, null);
      }
    } catch (e) {}
  }

  Future<void> clearMapLayout() async {
    try {
      storeLayout.clear();

      // Unassign all items that have a locationId
      final itemsToUnassign = _items
          .where((item) => item.locationId != null)
          .toList();
      for (var item in itemsToUnassign) {
        await assignItemToLocation(item.id, null);
      }
    } catch (e) {}
  }

  Future<void> updateItemLocationDetails(
    String itemId, {
    required String aisle,
    required int shelf,
    required String section,
    required String layer,
  }) async {
    try {
      await supabase
          .from('products')
          .update({
            // 'aisle': aisle,
            'shelf_level': shelf.toString(),
            // 'section': section,
            'bin_number': layer,
          })
          .eq('id', itemId);

      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(
          shelfLevel: shelf.toString(),
          binNumber: layer,
        );
      }
    } catch (e) {}
  }

  List<InventoryItem> get unassignedItems =>
      _items.where((item) => item.locationId == null).toList();

  List<InventoryItem> filterInventory({
    required String query,
    required String category,
  }) {
    final filtered = _items.where((item) {
      final matchesSearch =
          item.name.toLowerCase().contains(query.toLowerCase()) ||
          item.sku.toLowerCase().contains(query.toLowerCase());

      final matchesCategory =
          category == 'All' ||
          (category == 'Unassigned' && item.locationId == null) ||
          item.category == category;

      return matchesSearch && matchesCategory;
    }).toList();

    // Sort items: "No Location" first, then group by location, then alphabetize by name
    filtered.sort((a, b) {
      if (a.locationId == null && b.locationId != null) return -1;
      if (a.locationId != null && b.locationId == null) return 1;
      if (a.locationId != null && b.locationId != null) {
        final locCompare = a.locationId!.compareTo(b.locationId!);
        if (locCompare != 0) return locCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  List<String> getUniqueCategories() {
    final categories = _items.map((item) => item.category).toSet().toList();
    categories.sort();
    return ['All', 'Unassigned', ...categories];
  }

  InventoryItem prepareUpdatedItem({
    required InventoryItem originalItem,
    required String newName,
    required String newSku,
    required String newPrice,
    required String newStock,
    required String newMaxStock,
    required String newDesc,
    String? locationId,
    String? manufacturer,
    String? model,
    String? productSize,
    String? shelfLevel,
    String? binNumber,
    String? imageUrl,
    String? unit,
  }) {
    return originalItem.copyWith(
      name: newName,
      sku: newSku,
      price: double.tryParse(newPrice) ?? originalItem.price,
      quantity: double.tryParse(newStock) ?? originalItem.quantity,
      maxQuantity: double.tryParse(newMaxStock) ?? originalItem.maxQuantity,
      description: newDesc,
      locationId: locationId,
      manufacturer: manufacturer,
      model: model,
      productSize: productSize,
      shelfLevel: shelfLevel,
      binNumber: binNumber,
      imageUrl: imageUrl,
      unit: unit,
    );
  }

  InventoryItem createNewItem({
    required String name,
    required String sku,
    required String price,
    required String quantity,
    required String maxQuantity,
    required String category,
    required String description,
    String? mapLocationId,
    String? manufacturer,
    String? model,
    String? productSize,
    String? shelfLevel,
    String? binNumber,
    String? imageUrl,
    String unit = 'pcs',
  }) {
    double parsedQty = double.tryParse(quantity) ?? 0.0;
    double parsedMax = double.tryParse(maxQuantity) ?? parsedQty;

    return InventoryItem(
      id: '',
      name: name,
      sku: sku,
      price: double.tryParse(price) ?? 0.0,
      quantity: double.tryParse(quantity) ?? 0.0,
      maxQuantity: parsedMax == 0 ? 100 : parsedMax,
      category: category,
      description: description,
      locationId: mapLocationId,
      manufacturer: manufacturer,
      model: model,
      productSize: productSize,
      shelfLevel: shelfLevel,
      binNumber: binNumber,
      imageUrl: imageUrl ?? '',
      unit: unit,
    );
  }

  InventoryItem calculateCheckout(InventoryItem item, double quantity) {
    return item.copyWith(
      quantity: (item.quantity - quantity).clamp(0.0, 999999.0),
    );
  }

  InventoryItem? findItemByCode(String code) {
    try {
      return _items.firstWhere((item) => item.sku.trim() == code.trim());
    } catch (e) {
      return null;
    }
  }

  List<InventoryItem> searchInventory(String query) {
    if (query.isEmpty) return _items;

    final lowercaseQuery = query.toLowerCase();
    return _items.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery) ||
          item.sku.toLowerCase().contains(lowercaseQuery) ||
          item.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchStaff() async {
    final locId = activeLocationId;
    if (locId == null) return [];
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('location_id', locId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<bool> createStaff({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    final locId = activeLocationId;
    if (locId == null) return false;
    try {
      final hashedPassword = _hashPassword(password);

      await supabase.from('profiles').insert({
        'name': name,
        'username': username,
        'password': hashedPassword,
        'role': role,
        'location_id': locId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStaffRole(String id, String newRole) async {
    try {
      await supabase.from('profiles').update({'role': newRole}).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteStaff(String id) async {
    try {
      await supabase.from('profiles').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentUserId == null) return "User not logged in.";
    try {
      final hashedCurrentPassword = _hashPassword(currentPassword);
      final hashedNewPassword = _hashPassword(newPassword);

      // Verify current password
      final response = await supabase
          .from('profiles')
          .select('password')
          .eq('id', currentUserId!)
          .single();

      if (response['password'] != hashedCurrentPassword) {
        return "Incorrect current password.";
      }

      // Update to new password
      await supabase
          .from('profiles')
          .update({'password': hashedNewPassword})
          .eq('id', currentUserId!);
      return null;
    } catch (e) {
      return "An error occurred while changing the password.";
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactionHistory(
    String productId,
  ) async {
    try {
      final response = await supabase
          .from('transaction_history')
          .select('*, profiles(name, role)')
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllTransactionHistory() async {
    final locId = activeLocationId;
    if (locId == null) return [];
    try {
      final response = await supabase
          .from('transaction_history')
          .select('*, products(product_name, sku), profiles(name, role)')
          .eq('location_id', locId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> clearTransactionHistory() async {
    final locId = activeLocationId;
    if (locId == null) return;
    try {
      await supabase
          .from('transaction_history')
          .delete()
          .eq('location_id', locId);
    } catch (e) {}
  }

  // ==========================================
  // AI ANALYTICS & FORECASTING ENGINE
  // ==========================================

  Future<List<Map<String, dynamic>>> generateInventoryAnalytics({
    int days = 30,
    int leadTimeDays = 7,
  }) async {
    final locId = activeLocationId;
    if (locId == null) return [];

    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String();

      // Fetch checkout transactions in the past `days` to calculate velocity
      final response = await supabase
          .from('transaction_history')
          .select('product_id, quantity_change, created_at')
          .eq('location_id', locId)
          .eq('transaction_type', 'checkout')
          .gte('created_at', cutoffDate);

      final transactions = List<Map<String, dynamic>>.from(response);

      // Aggregate sales volume per product
      Map<String, int> salesData = {};
      for (var tx in transactions) {
        final String? pId = tx['product_id']?.toString();
        if (pId != null) {
          final int qty = (tx['quantity_change'] as num).abs().toInt();
          salesData[pId] = (salesData[pId] ?? 0) + qty;
        }
      }

      List<Map<String, dynamic>> analyticsList = [];

      for (var item in _items) {
        final totalSold = salesData[item.id] ?? 0;
        final dailySalesVelocity = totalSold / days;

        String classification;
        if (totalSold == 0) {
          classification = 'Dead Stock';
        } else if (dailySalesVelocity >= 1.0) {
          classification = 'Fast-Moving';
        } else {
          classification = 'Slow-Moving';
        }

        double daysUntilStockout = -1;
        DateTime? stockoutDate;
        if (dailySalesVelocity > 0) {
          daysUntilStockout = item.quantity / dailySalesVelocity;
          stockoutDate = DateTime.now().add(
            Duration(days: daysUntilStockout.floor()),
          );
        }

        int safetyStock = 0;
        int reorderPoint = 0;
        int optimalReorderQuantity = 0;

        if (classification == 'Fast-Moving') {
          safetyStock = (leadTimeDays * dailySalesVelocity * 1.5).ceil();
          reorderPoint =
              (leadTimeDays * dailySalesVelocity).ceil() + safetyStock;
          optimalReorderQuantity = (dailySalesVelocity * 30).ceil();
        } else if (classification == 'Slow-Moving') {
          safetyStock = (leadTimeDays * dailySalesVelocity * 1.0).ceil();
          reorderPoint =
              (leadTimeDays * dailySalesVelocity).ceil() + safetyStock;
          optimalReorderQuantity = (dailySalesVelocity * 15).ceil();
        } else {
          safetyStock = 0;
          reorderPoint = 0;
          optimalReorderQuantity = 0;
        }

        analyticsList.add({
          'item': item,
          'totalSoldLast30Days': totalSold,
          'dailySalesVelocity': dailySalesVelocity,
          'classification': classification,
          'daysUntilStockout': daysUntilStockout,
          'stockoutDate': stockoutDate,
          'safetyStock': safetyStock,
          'reorderPoint': reorderPoint,
          'optimalReorderQuantity': optimalReorderQuantity,
          'needsReorder':
              item.quantity <= reorderPoint && classification != 'Dead Stock',
        });
      }

      analyticsList.sort((a, b) {
        if (a['needsReorder'] && !b['needsReorder']) return -1;
        if (!a['needsReorder'] && b['needsReorder']) return 1;
        if (a['daysUntilStockout'] != -1 && b['daysUntilStockout'] != -1) {
          return (a['daysUntilStockout'] as double).compareTo(
            b['daysUntilStockout'] as double,
          );
        }
        return 0;
      });

      return analyticsList;
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // ORDER FULFILLMENT WORKFLOW
  // ==========================================

  Future<void> createCustomerOrder(List<CustomerOrderItem> items) async {
    final locId = activeLocationId;

    if (locId == null) {
      return;
    }

    try {
      // 1. Insert the order into the database
      final result = await supabase.from('orders').insert({
        'location_id': locId,
        'status': 'pending',
        'items': items.map((i) => i.toJson()).toList(),
        'created_by': currentUserNumericId,
      }).select();

      // 2. DEDUCT STOCK IMMEDIATELY (Reserve it)
      // This prevents double booking by updating the inventory instantly for all users
      for (var orderItem in items) {
        final index = _items.indexWhere((i) => i.id == orderItem.productId);
        if (index != -1) {
          final currentItem = _items[index];
          final updatedItem = calculateCheckout(
            currentItem,
            orderItem.quantity,
          );
          await updateItem(updatedItem);
        }
      }
    } catch (e) {}
  }

  Stream<List<CustomerOrder>> streamOrders() {
    final locId = activeLocationId;
    if (locId == null) return Stream.value([]);

    return supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('location_id', locId)
        .order('created_at', ascending: false)
        .map(
          (list) =>
              list.map((item) => CustomerOrder.fromSupabase(item)).toList(),
        );
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};
      if (newStatus == 'prepared') {
        updateData['prepared_by'] = currentUserNumericId;
      }
      await supabase.from('orders').update(updateData).eq('id', orderId);
    } catch (e) {}
  }

  Set<String>? _processingOrders;

  Future<void> completeOrder(CustomerOrder order) async {
    _processingOrders ??= {};
    if (_processingOrders!.contains(order.id)) return;
    _processingOrders!.add(order.id);

    try {
      // 0. Double-check order status to prevent unnecessary updates
      final checkOrder = await supabase
          .from('orders')
          .select('status')
          .eq('id', order.id)
          .single();
      if (checkOrder['status'] == 'completed') return;

      // 1. Update order status to completed ONLY.
      // Stock is NO LONGER deducted here because it was reserved in createCustomerOrder.
      await updateOrderStatus(order.id, 'completed');
    } catch (e) {
    } finally {
      _processingOrders!.remove(order.id);
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String name,
    required String email,
    required String location,
    required String phone,
  }) async {
    try {
      final updateData = {
        'name': name,
        'email': email.isEmpty ? null : email,
        'address': location,
        'phone': phone,
      };

      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', userId);
    } catch (e) {
      throw Exception("Failed to save changes to the database.");
    }
  }
  // ==========================================
  // ADMIN FUNCTIONS
  // ==========================================

  /// Allows an admin to forcefully reset a staff member's password
  Future<bool> adminResetUserPassword(
    String targetUserId,
    String newPassword,
  ) async {
    try {
      final hashedNewPassword = _hashPassword(newPassword);

      await supabase
          .from('profiles')
          .update({'password': hashedNewPassword})
          .eq('id', targetUserId);

      return true;
    } catch (e) {
      return false;
    }
  }
}
