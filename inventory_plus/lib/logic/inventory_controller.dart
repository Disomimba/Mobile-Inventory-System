import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import '../data/inventory.dart';

class InventoryController {
  final SupabaseClient supabase = Supabase.instance.client;

  List<MapElement> storeLayout = [];
  List<InventoryItem> _items = [];
  String? activeLocationId;
  String? currentUserRole;
  String? currentUserName;
  String? currentUserId;

  bool get isAdmin => currentUserRole?.toLowerCase() == 'admin';

  List<InventoryItem> get allItems => _items;

  void setLoggedInUser({
    required String name,
    required String id,
    required String role,
  }) {
    currentUserName = name;
    currentUserId = id;
    currentUserRole = role;
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

      print("Store Data Sync Complete: $userLocationId");
    } catch (e) {
      print("Error loading store data: $e");
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

      print("Layout saved to Supabase.");
    } catch (e) {
      print("Error saving layout: $e");
    }
  }

  Future<void> addItem(InventoryItem newItem) async {
    final locId = activeLocationId;
    if (locId == null) {
      print("Error: No activeLocationId found. Are you logged in?");
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

      print("SUCCESS: Item saved to Supabase with ID: ${savedItem.id}");
    } catch (e) {
      print("DATABASE ERROR: $e");
      rethrow;
    }
  }

  Future<void> _logTransaction({
    String? productId,
    required String type,
    required int quantityChange,
    required int newQuantity,
  }) async {
    final locId = activeLocationId;
    final userId = currentUserId;
    final userName = currentUserName ?? 'Unknown User';

    if (locId == null || userId == null) return;

    print("--- DEBUG TRANSACTION LOG ---");
    print("productId: $productId | locId: $locId | userId: $userId");

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
    } catch (e) {
      print("Error logging transaction: $e");
    }
  }

  // Uploads an image to Supabase Storage and returns the public URL
  Future<String?> uploadProductImage(File imageFile, String fileName) async {
    try {
      // Generate a unique path to prevent overwriting images with the same name
      final path = 'public/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await supabase.storage.from('product_images').upload(path, imageFile);
      
      final imageUrl = supabase.storage.from('product_images').getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  // Uploads an image from bytes (Required for Flutter Web)
  Future<String?> uploadImageBytes(Uint8List imageBytes, String fileName) async {
    try {
      final path = 'public/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await supabase.storage.from('product_images').uploadBinary(path, imageBytes);
      
      final imageUrl = supabase.storage.from('product_images').getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      print("Error uploading image bytes: $e");
      return null;
    }
  }

  Future<void> updateItem(InventoryItem updatedItem) async {
    try {
      final index = _items.indexWhere((item) => item.id == updatedItem.id);
      if (index != -1) {
        final oldItem = _items[index];
        final quantityChange = updatedItem.quantity - oldItem.quantity;

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
            'map_element_id':
                updatedItem.locationId, 
          })
          .eq('id', updatedItem.id);

      if (index != -1) {
        _items[index] = updatedItem;
      }
    } catch (e) {
      print("Error updating item: $e");
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      final index = _items.indexWhere((item) => item.id == id);
      await supabase.from('products').delete().eq('id', id);

      if (index != -1) {
        final itemToDelete = _items[index];
        _items.removeAt(index);
        await _logTransaction(
          productId: null, // Null to prevent Foreign Key constraint error on cascade delete
          type: 'delete',
          quantityChange: -itemToDelete.quantity,
          newQuantity: 0,
        );
      }
    } catch (e) {
      print("Error deleting item: $e");
    }
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
        _items[index] = InventoryItem(
          id: current.id,
          name: current.name,
          sku: current.sku,
          price: current.price,
          quantity: current.quantity,
          category: current.category,
          description: current.description,
          locationId: rackId,
          manufacturer: current.manufacturer,
          model: current.model,
          productSize: current.productSize,
          shelfLevel: current.shelfLevel,
          binNumber: current.binNumber,
          imageUrl: current.imageUrl,
        );
      }
    } catch (e) {
      print("Error assigning location: $e");
    }
  }

  Future<void> deleteMapElement(String elementId) async {
    try {
      storeLayout.removeWhere((item) => item.id == elementId);

      // Unassign all items that were assigned to this element
      final itemsToUnassign = _items.where((item) => item.locationId == elementId).toList();
      for (var item in itemsToUnassign) {
        await assignItemToLocation(item.id, null);
      }
    } catch (e) {
      print("Error deleting map element: $e");
    }
  }

  Future<void> clearMapLayout() async {
    try {
      storeLayout.clear();

      // Unassign all items that have a locationId
      final itemsToUnassign = _items.where((item) => item.locationId != null).toList();
      for (var item in itemsToUnassign) {
        await assignItemToLocation(item.id, null);
      }
    } catch (e) {
      print("Error clearing map layout: $e");
    }
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
            // NOTE: You may need to add 'aisle' and 'section' columns to your Supabase table if you want to save them!
            // 'aisle': aisle,
            'shelf_level': shelf.toString(),
            // 'section': section,
            'bin_number': layer, // Using bin_number to store the layer in this example
          })
          .eq('id', itemId);

      final index = _items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(shelfLevel: shelf.toString(), binNumber: layer);
      }
    } catch (e) {
      print("Error updating location details: $e");
    }
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
      
      final matchesCategory = category == 'All' || 
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
    required String newDesc,
    String? locationId,
    String? manufacturer,
    String? model,
    String? productSize,
    String? shelfLevel,
    String? binNumber,
    String? imageUrl,
  }) {
    return originalItem.copyWith(
      name: newName,
      sku: newSku,
      price: double.tryParse(newPrice) ?? originalItem.price,
      quantity: int.tryParse(newStock) ?? originalItem.quantity,
      description: newDesc,
      locationId: locationId,
      manufacturer: manufacturer,
      model: model,
      productSize: productSize,
      shelfLevel: shelfLevel,
      binNumber: binNumber,
      imageUrl: imageUrl,
    );
  }

  InventoryItem calculateCheckout(InventoryItem item, int quantity) {
    return item.copyWith(quantity: (item.quantity - quantity).clamp(0, 999999));
  }

  InventoryItem createNewItem({
    required String name,
    required String sku,
    required String price,
    required String quantity,
    required String category,
    required String description,
    String? mapLocationId,
    String? manufacturer,
    String? model,
    String? productSize,
    String? shelfLevel,
    String? binNumber,
    String? imageUrl,
  }) {
    return InventoryItem(
      id: '',
      name: name,
      sku: sku,
      price: double.tryParse(price) ?? 0.0,
      quantity: int.tryParse(quantity) ?? 0,
      category: category,
      description: description,
      locationId: mapLocationId,
      manufacturer: manufacturer,
      model: model,
      productSize: productSize,
      shelfLevel: shelfLevel,
      binNumber: binNumber,
      imageUrl: imageUrl ?? '',
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
      print("Error fetching staff: $e");
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
      print("Error creating staff: $e");
      return false;
    }
  }

  Future<bool> updateStaffRole(String id, String newRole) async {
    try {
      await supabase.from('profiles').update({'role': newRole}).eq('id', id);
      return true;
    } catch (e) {
      print("Error updating staff role: $e");
      return false;
    }
  }

  Future<bool> deleteStaff(String id) async {
    try {
      await supabase.from('profiles').delete().eq('id', id);
      return true;
    } catch (e) {
      print("Error deleting staff: $e");
      return false;
    }
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
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
      await supabase.from('profiles').update({'password': hashedNewPassword}).eq('id', currentUserId!);
      return null; // Returns null upon success
    } catch (e) {
      print("Error changing password: $e");
      return "An error occurred while changing the password.";
    }
  }

  Future<List<Map<String, dynamic>>> fetchTransactionHistory(String productId) async {
    try {
      final response = await supabase
          .from('transaction_history')
          .select('*, profiles(name, role)')
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Error fetching transaction history: $e");
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
      print("Error fetching all transaction history: $e");
      return [];
    }
  }

  // ==========================================
  // AI ANALYTICS & FORECASTING ENGINE
  // ==========================================

  /// Analyzes transaction history to generate actionable AI stock recommendations and demand forecasts.
  /// 1. AI Demand Forecasting -> Calculates "Predicted Stockout Date" based on sales velocity.
  /// 2. AI Stock Recommendation -> Classifies items (Fast/Slow/Dead) and calculates dynamic reorder points.
  Future<List<Map<String, dynamic>>> generateInventoryAnalytics({int days = 30, int leadTimeDays = 7}) async {
    final locId = activeLocationId;
    if (locId == null) return [];

    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days)).toIso8601String();

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
        final String? pId = tx['product_id'];
        if (pId != null) {
          // 'checkout' transactions log negative quantity changes, use absolute value
          final int qty = (tx['quantity_change'] as num).abs().toInt();
          salesData[pId] = (salesData[pId] ?? 0) + qty;
        }
      }

      List<Map<String, dynamic>> analyticsList = [];

      for (var item in _items) {
        final totalSold = salesData[item.id] ?? 0;
        final dailySalesVelocity = totalSold / days;
        
        // SOLUTION 2: AI Stock Recommendation (Classify based on velocity to solve Overstocking)
        String classification;
        if (totalSold == 0) {
          classification = 'Dead Stock';
        } else if (dailySalesVelocity >= 1.0) {
          classification = 'Fast-Moving';
        } else {
          classification = 'Slow-Moving';
        }

        // SOLUTION 1: AI Demand Forecasting (Predict Stockout Date to solve Delayed Procurement)
        int daysUntilStockout = -1;
        DateTime? stockoutDate;
        if (dailySalesVelocity > 0) {
          daysUntilStockout = (item.quantity / dailySalesVelocity).floor();
          stockoutDate = DateTime.now().add(Duration(days: daysUntilStockout));
        }

        // Dynamic Reorder Math (Calculates exact safety stock & prevents stockouts)
        int safetyStock = 0;
        int reorderPoint = 0;
        int optimalReorderQuantity = 0;

        if (classification == 'Fast-Moving') {
          safetyStock = (leadTimeDays * dailySalesVelocity * 1.5).ceil(); // Increased safety buffer
          reorderPoint = (leadTimeDays * dailySalesVelocity).ceil() + safetyStock;
          optimalReorderQuantity = (dailySalesVelocity * 30).ceil(); // Restock 30 days worth
        } else if (classification == 'Slow-Moving') {
          safetyStock = (leadTimeDays * dailySalesVelocity * 1.0).ceil(); // Standard safety buffer
          reorderPoint = (leadTimeDays * dailySalesVelocity).ceil() + safetyStock;
          optimalReorderQuantity = (dailySalesVelocity * 15).ceil(); // Restock only 15 days worth to prevent tied capital
        } else {
          // Dead Stock: Restrict reordering to prevent overstocking
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
          'needsReorder': item.quantity <= reorderPoint && classification != 'Dead Stock',
        });
      }

      // Sort by urgency: Items needing reorder first, then by days until stockout
      analyticsList.sort((a, b) {
        if (a['needsReorder'] && !b['needsReorder']) return -1;
        if (!a['needsReorder'] && b['needsReorder']) return 1;
        if (a['daysUntilStockout'] != -1 && b['daysUntilStockout'] != -1) {
          return (a['daysUntilStockout'] as int).compareTo(b['daysUntilStockout'] as int);
        }
        return 0;
      });

      return analyticsList;

    } catch (e) {
      print("Error generating inventory analytics: $e");
      return [];
    }
  }

  // ==========================================
  // ORDER FULFILLMENT WORKFLOW
  // ==========================================

  Future<void> createCustomerOrder(List<CustomerOrderItem> items) async {
    final locId = activeLocationId;
    if (locId == null) return;
    try {
      await supabase.from('orders').insert({
        'location_id': locId,
        'status': 'pending',
        'items': items.map((i) => i.toJson()).toList(),
      });
    } catch (e) {
      print("Error creating order: $e");
    }
  }

  Stream<List<CustomerOrder>> streamOrders() {
    final locId = activeLocationId;
    if (locId == null) return Stream.value([]);

    return supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('location_id', locId)
        .order('created_at', ascending: false)
        .map((list) => list.map((item) => CustomerOrder.fromSupabase(item)).toList());
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await supabase.from('orders').update({'status': newStatus}).eq('id', orderId);
    } catch (e) {
      print("Error updating order status: $e");
    }
  }

  Future<void> completeOrder(CustomerOrder order) async {
    try {
      // 1. Update order status to completed
      await updateOrderStatus(order.id, 'completed');

      // 2. Deduct stock for each item in the order
      for (var orderItem in order.items) {
        final index = _items.indexWhere((i) => i.id == orderItem.productId);
        if (index != -1) {
          final currentItem = _items[index];
          final updatedItem = calculateCheckout(currentItem, orderItem.quantity);
          await updateItem(updatedItem); // This also handles logging the 'checkout' transaction
        }
      }
    } catch (e) {
      print("Error completing order and deducting stock: $e");
    }
  }
}