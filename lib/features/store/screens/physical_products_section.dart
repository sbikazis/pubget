// lib/features/store/physical_products_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/theme/app_colors.dart';
import 'package:pubget/providers/store_provider.dart';
import 'physical_product_card.dart';

class PhysicalProductsSection extends StatelessWidget {
  const PhysicalProductsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const textSecondary = AppColors.darkTextSecondary;
    final store = context.watch<StoreProvider>();

    if (store.isLoadingPhysicalProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.physicalProducts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 58, color: textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'سوق الأنمي الواقعي 🎒',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              'تجهّز لاقتناء مجسمات حصرية وملابس بطابع ياباني!',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: store.physicalProducts.length,
      itemBuilder: (context, index) {
        final product = store.physicalProducts[index];
        return PhysicalProductCard(product: product);
      },
    );
  }
}