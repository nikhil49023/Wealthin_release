import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/shopping_assistant.dart';
import '../../core/services/web_scraper_service.dart';
import '../../core/theme/indian_theme.dart';
import '../../main.dart' show authService;

// ─────────────────────────────────────────────────────────────────────────────
//  SHOPPING ASSISTANT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ShoppingAssistantScreen extends StatefulWidget {
  const ShoppingAssistantScreen({super.key});

  @override
  State<ShoppingAssistantScreen> createState() =>
      _ShoppingAssistantScreenState();
}

class _ShoppingAssistantScreenState extends State<ShoppingAssistantScreen> {
  late ShoppingAssistant _assistant;
  late TextEditingController _queryController;
  late TextEditingController _locationController;
  late TextEditingController _budgetController;

  ShoppingRecommendation? _recommendation;
  BusinessFindingResult? _businesses;
  ComparisonResult? _comparison;
  bool _isLoading = false;
  String _activeTab = 'products';
  String? _error;

  @override
  void initState() {
    super.initState();
    _assistant = shoppingAssistant;
    _queryController = TextEditingController();
    _locationController = TextEditingController();
    _budgetController = TextEditingController();
    _initializeAssistant();
  }

  Future<void> _initializeAssistant() async {
    try {
      await _assistant.initialize();
      debugPrint('[ShoppingScreen] Assistant initialized');
    } catch (e) {
      setState(() => _error = 'Failed to initialize: $e');
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts() async {
    if (_queryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a product query')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = authService.currentUser?.uid ?? 'anonymous';
      final result = await _assistant.getRecommendations(
        _queryController.text,
        userId: userId,
        budget: _budgetController.text.isEmpty ? null : _budgetController.text,
      );

      setState(() {
        _recommendation = result;
        _activeTab = 'products';
      });
    } catch (e) {
      setState(() => _error = 'Search failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchBusinesses() async {
    if (_queryController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter business type and location'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = authService.currentUser?.uid ?? 'anonymous';
      final result = await _assistant.findBusinesses(
        _queryController.text,
        _locationController.text,
        userId: userId,
      );

      setState(() {
        _businesses = result;
        _activeTab = 'businesses';
      });
    } catch (e) {
      setState(() => _error = 'Search failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _compareProducts() async {
    if (_queryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a product to compare')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = authService.currentUser?.uid ?? 'anonymous';
      final result = await _assistant.compareProducts(
        _queryController.text,
        userId: userId,
      );

      setState(() {
        _comparison = result;
        _activeTab = 'comparison';
      });
    } catch (e) {
      setState(() => _error = 'Comparison failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🛍️ Shopping Assistant',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Section
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What are you looking for?',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Product Query
                    TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: 'e.g., laptop, software subscription',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Budget
                    TextField(
                      controller: _budgetController,
                      decoration: InputDecoration(
                        hintText: 'Budget (optional)',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Location
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: 'Location (for business search)',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _searchProducts,
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('Find Products'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _compareProducts,
                            icon: const Icon(Icons.compare_arrows),
                            label: const Text('Compare'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _searchBusinesses,
                            icon: const Icon(Icons.business),
                            label: const Text('Businesses'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Loading Indicator
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Searching across marketplaces...',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            // Error Message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // Results Section
            if (_recommendation != null && _activeTab == 'products')
              _buildProductRecommendations(_recommendation!),
            if (_businesses != null && _activeTab == 'businesses')
              _buildBusinessResults(_businesses!),
            if (_comparison != null && _activeTab == 'comparison')
              _buildComparisonResults(_comparison!),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRecommendations(ShoppingRecommendation rec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Recommendation',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rec.recommendation != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Text(
                      rec.recommendation!,
                      style: GoogleFonts.poppins(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  rec.analysis,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Found ${rec.products.length} Products',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...rec.products.map(
          (product) => _buildProductCard(product),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          product.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.source.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  product.price,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              product.rating ?? 'N/A',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text('⭐'),
          ],
        ),
        onTap: () {
          // Open product URL
          debugPrint('Opening: ${product.url}');
        },
      ),
    );
  }

  Widget _buildBusinessResults(BusinessFindingResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Business Analysis',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              result.analysis,
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Top Matches',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...result.topMatches.map(
          (business) => _buildBusinessCard(business),
        ),
      ],
    );
  }

  Widget _buildBusinessCard(Business business) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          business.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              business.location,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              business.rating ?? 'N/A',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text('⭐'),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonResults(ComparisonResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Comparison',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              result.analysis,
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
