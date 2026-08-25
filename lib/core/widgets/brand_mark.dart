import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The FinGenius AI "Ascend" mark, rendered from the vector master so the
/// in-app logo always matches assets/brand/.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'FinGenius AI logo',
        image: true,
        child: SvgPicture.asset(
          'assets/brand/fingenius_mark.svg',
          width: size,
          height: size,
        ),
      );
}
