import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/place.dart';

const placeIcons = <String, IconData>{
  'kitchen': Icons.kitchen_rounded,
  'weekend': Icons.weekend_rounded,
  'bathtub': Icons.bathtub_rounded,
  'cake': Icons.cake_rounded,
  'school': Icons.school_rounded,
  'park': Icons.park_rounded,
  'shopping_basket': Icons.shopping_basket_rounded,
  'sports_esports': Icons.sports_esports_rounded,
  'local_cafe': Icons.local_cafe_rounded,
  'medical_services': Icons.medical_services_rounded,
  'local_library': Icons.local_library_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  'directions_bus': Icons.directions_bus_rounded,
  'account_balance': Icons.account_balance_rounded,
  'biotech': Icons.biotech_rounded,
  'work': Icons.work_rounded,
  'account_balance_wallet': Icons.history_edu_rounded,
  'co_present': Icons.co_present_rounded,
  'sports_bar': Icons.sports_bar_rounded,
  'content_cut': Icons.content_cut_rounded,
  'restaurant': Icons.restaurant_rounded,
  'local_post_office': Icons.local_post_office_rounded,
  'local_pharmacy': Icons.local_pharmacy_rounded,
  'train': Icons.train_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'umbrella': Icons.umbrella_rounded,
  'bakery': Icons.bakery_dining_rounded,
  'teacup': Icons.emoji_food_beverage_rounded,
};

/// Backdrop for places whose painted illustration hasn't been produced yet.
class StorybookBackdrop extends StatelessWidget {
  final Place place;
  final double iconSize;
  const StorybookBackdrop({super.key, required this.place, this.iconSize = 160});
  @override
  Widget build(BuildContext context) {
    final c = Color(place.color);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(c, Colors.white, .25)!, c, Color.lerp(c, BL.ink, .45)!]),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -iconSize * .2,
            bottom: -iconSize * .15,
            child: Icon(placeIcons[place.icon] ?? Icons.place_rounded, size: iconSize * 1.6, color: Colors.white.withValues(alpha: .10)),
          ),
          Positioned(
            left: -40,
            top: -40,
            child: Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .07)),
            ),
          ),
          // soft paper grain
          Positioned.fill(child: CustomPaint(painter: _GrainPainter())),
        ],
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white.withValues(alpha: .035);
    for (var i = 0; i < 260; i++) {
      final x = (i * 97.0 % s.width), y = (i * 61.0 % s.height);
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class PlaceImage extends StatelessWidget {
  final Place place;
  final BoxFit fit;
  const PlaceImage(this.place, {super.key, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) => place.image == null
      ? StorybookBackdrop(place: place, iconSize: 90)
      : Image.asset(
          place.image!,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => StorybookBackdrop(place: place, iconSize: 90),
        );
}
