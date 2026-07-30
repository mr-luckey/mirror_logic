import 'package:flutter/material.dart';

/// Metal wall torch (no flame).
class MedievalTorch extends StatelessWidget {
  const MedievalTorch({
    super.key,
    this.width = 56,
    this.height = 96,
    this.flip = false,
  });

  final double width;
  final double height;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final torch = SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/images/medieval/torch_base_cut.png',
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/medieval/torch_cut.png',
          fit: BoxFit.contain,
        ),
      ),
    );

    if (flip) {
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: torch,
      );
    }
    return torch;
  }
}
