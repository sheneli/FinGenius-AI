import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Friendly FinGenius mascot ("Genie", the savings jar) used in empty states,
/// onboarding and auth. Original artwork — no third-party illustrations.
enum MascotMood { happy, searching }

class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 140, this.mood = MascotMood.happy});
  final double size;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SvgPicture.asset(
          mood == MascotMood.happy
              ? 'assets/illustrations/mascot_genie.svg'
              : 'assets/illustrations/mascot_empty.svg',
          width: size,
          height: size,
        ),
      );
}
