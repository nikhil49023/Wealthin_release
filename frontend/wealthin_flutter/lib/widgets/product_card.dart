import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/wealthin_theme.dart';

/// Product Card with clickable link - Used for AI search results
class ProductCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? price;
  final String? imageUrl;
  final String? productUrl;
  final String? source;
  final double? rating;
  final VoidCallback? onTap;
  
  const ProductCard({
    super.key,
    required this.title,
    this.subtitle,
    this.price,
    this.imageUrl,
    this.productUrl,
    this.source,
    this.rating,
    this.onTap,
  });
  
  Future<void> _launchUrl(BuildContext context) async {
    if (productUrl == null || productUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No link available for this product'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    final uri = Uri.tryParse(productUrl!);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the link'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLink = productUrl != null && productUrl!.isNotEmpty;
    
    return GestureDetector(
      onTap: onTap ?? () => _launchUrl(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image or placeholder
            if (imageUrl != null && imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 120,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => _buildImagePlaceholder(theme),
                  memCacheHeight: 240,  // Cache at 2x height for quality
                ),
              )
            else
              _buildImagePlaceholder(theme),
              
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  const SizedBox(height: 8),
                  
                  // Price and rating row
                  Row(
                    children: [
                      if (price != null && price!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: WealthInTheme.regalGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            price!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: WealthInTheme.vintageGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (rating != null) ...[
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              rating!.toStringAsFixed(1),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      if (source != null)
                        Text(
                          source!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                  
                  // View button
                  if (hasLink) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Product',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
  
  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 32,
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Horizontal scrollable product list
class ProductCardList extends StatelessWidget {
  final List<ProductCardData> products;
  final String? title;
  
  const ProductCardList({
    super.key,
    required this.products,
    this.title,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (products.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 180,
                child: ProductCard(
                  title: product.title,
                  subtitle: product.subtitle,
                  price: product.price,
                  imageUrl: product.imageUrl,
                  productUrl: product.productUrl,
                  source: product.source,
                  rating: product.rating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Data class for product card
class ProductCardData {
  final String title;
  final String? subtitle;
  final String? price;
  final String? imageUrl;
  final String? productUrl;
  final String? source;
  final double? rating;
  
  const ProductCardData({
    required this.title,
    this.subtitle,
    this.price,
    this.imageUrl,
    this.productUrl,
    this.source,
    this.rating,
  });
  
  factory ProductCardData.fromJson(Map<String, dynamic> json) {
    return ProductCardData(
      title: json['title'] ?? json['name'] ?? 'Unknown Product',
      subtitle: json['subtitle'] ?? json['description'],
      price: json['price']?.toString(),
      imageUrl: json['image'] ?? json['image_url'] ?? json['imageUrl'],
      productUrl: json['url'] ?? json['link'] ?? json['productUrl'],
      source: json['source'] ?? json['store'],
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

/// Parse products from AI response text
List<ProductCardData> parseProductsFromResponse(String response) {
  final products = <ProductCardData>[];
  
  // Pattern to match product entries with markdown links
  // Format: [ProductName](URL) - ₹Price
  final linkPattern = RegExp(
    r'\[([^\]]+)\]\(([^)]+)\)(?:\s*[-–]\s*(₹[\d,]+(?:\.\d{2})?))?',
    multiLine: true,
  );
  
  for (final match in linkPattern.allMatches(response)) {
    final title = match.group(1) ?? '';
    final url = match.group(2) ?? '';
    final price = match.group(3);
    
    if (title.isNotEmpty && url.isNotEmpty) {
      // Determine source from URL
      String? source;
      if (url.contains('amazon')) {
        source = 'Amazon';
      } else if (url.contains('flipkart')) {
        source = 'Flipkart';
      } else if (url.contains('myntra')) {
        source = 'Myntra';
      } else if (url.contains('ajio')) {
        source = 'Ajio';
      }
      
      products.add(ProductCardData(
        title: title,
        price: price,
        productUrl: url,
        source: source,
      ));
    }
  }
  
  // Also try to parse simple list items with prices
  // Format: - Product Name - ₹Price
  if (products.isEmpty) {
    final listPattern = RegExp(
      r'[-•]\s*([^-\n]+)\s*[-–]\s*(₹[\d,]+(?:\.\d{2})?)',
      multiLine: true,
    );
    
    for (final match in listPattern.allMatches(response)) {
      final title = match.group(1)?.trim() ?? '';
      final price = match.group(2);
      
      if (title.isNotEmpty) {
        products.add(ProductCardData(
          title: title,
          price: price,
        ));
      }
    }
  }
  
  return products;
}
