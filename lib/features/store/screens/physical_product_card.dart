// lib/features/store/physical_product_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pubget/core/theme/app_colors.dart';
import 'package:pubget/models/physical_product_model.dart';

class PhysicalProductCard extends StatelessWidget {
  final PhysicalProductModel product;

  const PhysicalProductCard({Key? key, required this.product}) : super(key: key);

  Future<void> _openAffiliateLink(BuildContext context) async {
    final uri = Uri.tryParse(product.affiliateUrl);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر فتح الرابط، حاول مرة أخرى'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardColor = AppColors.darkCard;
    const textPrimary = AppColors.darkTextPrimary;
    const textSecondary = AppColors.darkTextSecondary;

    return GestureDetector(
      onTap: () => _openAffiliateLink(context),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: Colors.black12,
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 32),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.price,
                        style: const TextStyle(
                          color: Color(0xFF00FF87),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product.rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              product.rating!.toStringAsFixed(1),
                              style: const TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}