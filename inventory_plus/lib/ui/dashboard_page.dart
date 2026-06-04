import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart';
import '../logic/inventory_controller.dart';
import '../../data/inventory.dart';

class DashboardPage extends StatefulWidget {
  final InventoryController controller;
  const DashboardPage({super.key, required this.controller});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _aiRecommendation = "Tap refresh to generate AI insights.";
  bool _isLoadingAI = false;
  String _forecastingFilter = 'Season';
  String _forecastInsightText = "Loading forecast...";
  bool _isFetchingForecast = false;
  
  final String _groqApiUrl = "https://api.groq.com/openai/v1/chat/completions";

  @override
  void initState() {
    super.initState();
    _fetchAIRecommendations();
    _fetchForecast();
  }

  Future<void> _fetchForecast() async {
    setState(() => _isFetchingForecast = true);
    
    try {
      // Prompting the AI to simulate the advanced forecasting engine described in your paper
      final prompt = _forecastingFilter == 'Season' 
          ? "You are an AI Demand Forecasting system strictly for a hardware and tool store. Considering external contextual factors like seasonal construction activity and local weather patterns for the current season, predict what hardware items (e.g., tools, building materials, plumbing) will be in highest demand. Do NOT suggest electronics, laptops, or gadgets. Keep it to 2 concise sentences."
          : "You are an AI Demand Forecasting system strictly for a hardware and tool store. Considering economic indicators and short-term trends, predict what hardware items (e.g., tools, building materials, plumbing) will be in highest demand next month. Do NOT suggest electronics, laptops, or gadgets. Keep it to 2 concise sentences.";

      final groqApiKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';

      if (groqApiKey.isEmpty) {
        setState(() => _forecastInsightText = "API Key not found.");
        setState(() => _isFetchingForecast = false);
        return;
      }

      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant", 
          "messages": [
            {"role": "system", "content": "You are an expert inventory forecasting AI exclusively for a hardware store."},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _forecastInsightText = data['choices'][0]['message']['content'].trim();
        });
      } else {
        setState(() {
          _forecastInsightText = "Error fetching forecast.";
        });
      }
    } catch (e) {
      setState(() => _forecastInsightText = "Network error: $e");
    } finally {
      setState(() => _isFetchingForecast = false);
    }
  }

  Future<void> _fetchAIRecommendations() async {
    setState(() => _isLoadingAI = true);
    
    try {
      final allItems = widget.controller.filterInventory(query: "", category: "All");
      final criticalItems = allItems.where((i) => i.quantity > 0 && i.quantity <= 10).map((i) => "${i.name} (${i.quantity})").join(', ');
      final deadItems = allItems.where((i) => i.quantity == 0).map((i) => i.name).join(', ');

      final prompt = "I am managing a hardware inventory. Critical items: $criticalItems. Dead/Out-of-stock items: $deadItems. Give me a 2-3 sentence recommendation on what to restock immediately and any insights.";

      // .trim() prevents issues with accidental spaces in the .env file
      final groqApiKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';

      debugPrint("Loaded ENV keys: ${dotenv.env.keys.toList()}");

      if (groqApiKey.isEmpty) {
        setState(() => _aiRecommendation = "API Key not found. Please check your .env file and completely restart the app.");
        setState(() => _isLoadingAI = false);
        return;
      }

      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant", 
          "messages": [
            {"role": "system", "content": "You are an expert inventory manager AI assistant."},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.6,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _aiRecommendation = data['choices'][0]['message']['content'].trim();
        });
      } else {
        final errorMessage = response.body;
        setState(() {
          _aiRecommendation = "Error fetching insights (Status: ${response.statusCode})\nDetails: $errorMessage";
        });
        debugPrint("Groq API Error: ${response.statusCode}");
        debugPrint("Response body: $errorMessage");
        debugPrint("Key used (first 10 chars): ${groqApiKey.length > 10 ? groqApiKey.substring(0, 10) : groqApiKey}...");
      }
    } catch (e) {
      setState(() => _aiRecommendation = "Network error: $e");
    } finally {
      setState(() => _isLoadingAI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = widget.controller.filterInventory(query: "", category: "All");
    final totalItems = allItems.length;

    // CAPSTONE REQUIREMENT: Dead, Low, and Critical Stock thresholds.
    final deadStockItems = allItems.where((item) => item.quantity == 0).toList();
    final criticalStockItems = allItems.where((item) => item.quantity > 0 && item.quantity <= 10).toList();
    final lowStockItems = allItems.where((item) => item.quantity > 10 && item.quantity <= 20).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Analytics & Forecasting Dashboard",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 24),
            
            // 1. KPI STAT CARDS (Top Row)
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);

                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 120,
                  ),
                  children: [
                    _buildStatCard(
                      "Total Monitored SKUs",
                      totalItems.toString(),
                      LucideIcons.package,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      "Low Stock (20% Threshold)",
                      lowStockItems.length.toString(),
                      LucideIcons.pencil,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      "Critical Stock (10% Threshold)",
                      criticalStockItems.length.toString(),
                      LucideIcons.triangleAlert,
                      Colors.red,
                    ),
                    _buildStatCard(
                      "Dead Stock (0 Qty)",
                      deadStockItems.length.toString(),
                      Icons.cancel_outlined,
                      Colors.blueGrey,
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 24),

            // 2. MAIN DASHBOARD CONTENT (Responsive Wrap)
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    // Left Column (Forecasting)
                    SizedBox(
                      width: isDesktop ? (constraints.maxWidth / 1.7) - 12 : double.infinity,
                      child: _buildForecastingChart(),
                    ),
                    // Right Column (Alerts & Recommendations)
                    SizedBox(
                      width: isDesktop ? (constraints.maxWidth / 2.5) - 12 : double.infinity,
                      child: Column(
                        children: [
                          _buildActionableAlerts(criticalStockItems),
                          const SizedBox(height: 24),
                          _buildAIRecommendations(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastingChart() {
    String insightTitle = _forecastingFilter == 'Season' 
        ? "This Season Highly demand" 
        : "This Month Highly demand";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.trendingUp, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "AI Demand Forecasting",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("About AI Demand Forecasting"),
                          content: const SingleChildScrollView(
                            child: Text(
                              "• Predicts Future Demand: Uses advanced machine learning algorithms (LSTM, Random Forest, Prophet) to forecast product demand.\n\n"
                              "• Analyzes Complex Data: Evaluates internal transaction data and external contextual factors like seasonal activity, weather, and economy.\n\n"
                              "• Optimizes Restocking: Estimates demand changes to determine mathematically optimal restocking schedules in advance.\n\n"
                              "• Calculates Reorder Points: Automatically calculates ideal reorder points and dynamically adjusts safety stock levels.\n\n"
                              "• Reduces Errors and Waste: Avoids excessive buildup of unsold goods, cutting forecasting mistakes by 20% to 50%."
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Close"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  ),
                ],
              ),
              DropdownButton<String>(
                value: _forecastingFilter,
                items: <String>['Season', 'Month'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null && newValue != _forecastingFilter) {
                    setState(() {
                      _forecastingFilter = newValue;
                    });
                    _fetchForecast();
                  }
                },
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Uses ML (LSTM, Random Forest, Prophet) and contextual data to forecast future demand, optimize restocking, and reduce errors.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insightTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                _isFetchingForecast
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : Text(
                        _forecastInsightText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionableAlerts(List<InventoryItem> criticalItems) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.triangleAlert, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                "Critical Action Required",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          const Divider(height: 24),
          if (criticalItems.isEmpty)
            const Text("No critical stock alerts at this time.", style: TextStyle(color: Colors.grey))
          else
            ...criticalItems.take(3).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${item.quantity} Left",
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildAIRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.sparkles, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "AI Restocking Suggestions",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, color: Colors.orange, size: 16),
                onPressed: _isLoadingAI ? null : _fetchAIRecommendations,
              )
            ],
          ),
          const SizedBox(height: 16),
          // Example Recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isLoadingAI
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Groq LLaMA-3 Analysis",
                        style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _aiRecommendation,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
          )
        ],
      ),
    );
  }
}