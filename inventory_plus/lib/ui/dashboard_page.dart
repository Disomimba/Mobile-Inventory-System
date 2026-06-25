import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart';
import '../logic/inventory_controller.dart';
import '../data/inventory.dart';

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

  bool _isBulletedFormat = true;

  final String _groqApiUrl = "https://api.groq.com/openai/v1/chat/completions";

  @override
  void initState() {
    super.initState();
    _fetchAIRecommendations();
    _fetchForecast();
  }

  String _getCurrentMonth() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[DateTime.now().month - 1];
  }

  Future<void> _fetchForecast() async {
    if (!mounted) return;
    setState(() => _isFetchingForecast = true);

    try {
      final currentMonth = _getCurrentMonth();
      String forecastingContext;
      String formatInstruction;

      if (_forecastingFilter == 'Season') {
        forecastingContext =
            "Focus purely on the upcoming Philippine seasonal and climate shifts (e.g., entering the rainy/typhoon season or summer heat) based on the current month.";
      } else {
        forecastingContext =
            "Focus strictly on short-term hardware sales trends, local economic activities, and month-to-month demand patterns.";
      }

      if (_isBulletedFormat) {
        formatInstruction =
            "Format the output as a professional, clean bulleted list using the '•' symbol. Recommend SPECIFIC ITEM NAMES in ALL CAPS for emphasis, followed by a brief 5-word reason. Example: '• ROOF SEALANT: Approaching rainy season.' DO NOT use markdown like asterisks (**).";
      } else {
        formatInstruction =
            "Format the output as a professional, concise executive summary paragraph (maximum 3 sentences). DO NOT list specific item names. Instead, explain the upcoming trend and recommend broad PRODUCT CATEGORIES (e.g., 'waterproofing materials', 'structural reinforcements'). DO NOT use markdown like asterisks (**).";
      }

      final prompt =
          """
      You are an AI Demand Forecasting system strictly for a hardware store located in the Philippines. 
      The current month is $currentMonth.
      $forecastingContext
      $formatInstruction
      Do NOT suggest electronics or gadgets. Do not include any conversational intro or outro text.
      """;

      final groqApiKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';

      if (groqApiKey.isEmpty) {
        if (!mounted) return;
        setState(() {
          _forecastInsightText = "API Key not found.";
          _isFetchingForecast = false;
        });
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
            {
              "role": "system",
              "content":
                  "You are a professional, highly analytical inventory forecaster in the Philippines.",
            },
            {"role": "user", "content": prompt},
          ],
          "temperature": 0.2,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawContent = data['choices'][0]['message']['content'].trim();
        String cleanContent = rawContent.replaceAll(RegExp(r'\*+'), '');

        setState(() {
          _forecastInsightText = cleanContent;
        });
      } else {
        setState(() {
          _forecastInsightText = "Error fetching forecast.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _forecastInsightText = "Network error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingForecast = false);
      }
    }
  }

  Future<void> _fetchAIRecommendations() async {
    if (!mounted) return;
    setState(() => _isLoadingAI = true);

    try {
      final allItems = widget.controller.filterInventory(
        query: "",
        category: "All",
      );

      final criticalItems = allItems
          .where((i) => i.quantity > 0 && i.quantity <= 10)
          .map((i) => "${i.name} (Qty: ${i.quantity})")
          .join(', ');

      final deadItems = allItems
          .where((i) => i.quantity == 0)
          .map((i) => i.name)
          .join(', ');

      // UPDATED PROMPT: Merged logic with justification at the end
      final prompt =
          """
      I manage a hardware store. Here is my internal inventory data:
      Out-of-stock items: ${deadItems.isEmpty ? 'None' : deadItems}. 
      Low Stock (1-10 qty) items: ${criticalItems.isEmpty ? 'None' : criticalItems}. 

      Provide a strict INTERNAL restocking action plan.
      Follow these strict rules:
      1. Use the '•' symbol for bullet points.
      2. Write specific ITEM NAMES in ALL CAPS. DO NOT use markdown formatting like asterisks (**).
      3. Create a single section titled "URGENT REPLENISH".
      4. List each item in this format:
         1. [ITEM NAME]
            - [Brief 1-sentence reason for urgency]
            - [Recommended replenishment quantity]
      5. End the message with a single paragraph of justification explaining why these specific items were prioritized to maximize store revenue and customer satisfaction.
      6. Keep it extremely brief. No conversational filler.
      """;

      final groqApiKey = dotenv.env['GROQ_API_KEY']?.trim() ?? '';

      if (groqApiKey.isEmpty) {
        if (!mounted) return;
        setState(() {
          _aiRecommendation = "API Key not found.";
          _isLoadingAI = false;
        });
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
            {
              "role": "system",
              "content":
                  "You are a professional inventory manager. You follow formatting instructions exactly.",
            },
            {"role": "user", "content": prompt},
          ],
          "temperature": 0.1,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawContent = data['choices'][0]['message']['content'].trim();
        // Forcefully strip markdown
        String cleanContent = rawContent.replaceAll(RegExp(r'\*+'), '');

        setState(() {
          _aiRecommendation = cleanContent;
        });
      } else {
        setState(() => _aiRecommendation = "Error fetching insights.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiRecommendation = "Network error: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAI = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = widget.controller.filterInventory(
      query: "",
      category: "All",
    );
    final totalItems = allItems.length;

    final deadStockItems = allItems
        .where((item) => item.quantity == 0)
        .toList();
    final criticalStockItems = allItems
        .where((item) => item.quantity > 0 && item.quantity <= 10)
        .toList();
    final lowStockItems = allItems
        .where((item) => item.quantity > 10 && item.quantity <= 20)
        .toList();

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

            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;

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

            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(
                      width: isDesktop
                          ? (constraints.maxWidth / 1.7) - 12
                          : double.infinity,
                      child: _buildForecastingChart(),
                    ),
                    SizedBox(
                      width: isDesktop
                          ? (constraints.maxWidth / 2.5) - 12
                          : double.infinity,
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
        ? "Seasonal High-Demand Predictions"
        : "Next Month Demand Predictions";

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
                  const Icon(
                    LucideIcons.trendingUp,
                    color: Colors.blue,
                    size: 20,
                  ),
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
                              "• Predicts Future Demand: Uses LLM reasoning based on seasonal and economic trends.\n\n"
                              "• Optimizes Restocking: Estimates demand changes to determine optimal restocking schedules.\n\n"
                              "• Note: This relies on external contextual data (seasons/economy) rather than your local transaction history.",
                              style: TextStyle(height: 1.5),
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
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isBulletedFormat
                            ? LucideIcons.alignHorizontalJustifyStart400
                            : LucideIcons.list,
                        color: Colors.blue.shade700,
                        size: 18,
                      ),
                      tooltip: _isBulletedFormat
                          ? "Switch to Paragraph Format"
                          : "Switch to Bulleted List",
                      onPressed: () {
                        setState(() => _isBulletedFormat = !_isBulletedFormat);
                        _fetchForecast();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _forecastingFilter,
                        items: <String>['Season', 'Month'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null &&
                              newValue != _forecastingFilter) {
                            setState(() => _forecastingFilter = newValue);
                            _fetchForecast();
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Uses contextual market data to forecast future demand and optimize restocking.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 250,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insightTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.blue.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isFetchingForecast
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Text(
                              _forecastInsightText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF334155),
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                            ),
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

  Widget _buildActionableAlerts(List<InventoryItem> criticalItems) {
    final showViewAll = criticalItems.length > 5;
    final itemsToShow = criticalItems.take(5).toList();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.triangleAlert, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Restock Priority",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              if (showViewAll)
                TextButton(
                  onPressed: () => _showAllAlertsModal(criticalItems),
                  child: const Text(
                    "View All",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          if (criticalItems.isEmpty)
            const Text(
              "No critical stock alerts at this time.",
              style: TextStyle(color: Colors.grey),
            )
          else
            ...itemsToShow.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${item.quantity} ${item.unit}",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllAlertsModal(List<InventoryItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "All Critical Items",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${item.quantity} ${item.unit}",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  // HEADER RENAMED:
                  Text(
                    "AI Restocking Recommendation",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  LucideIcons.refreshCw,
                  color: Colors.orange,
                  size: 16,
                ),
                onPressed: _isLoadingAI ? null : _fetchAIRecommendations,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: _isLoadingAI
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  )
                : Text(
                    _aiRecommendation,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 13,
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
