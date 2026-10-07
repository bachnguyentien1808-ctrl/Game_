import 'package:flutter/material.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';

const memoryIcons = <IconData>[
  Icons.pets,
  Icons.rocket_launch,
  Icons.favorite,
  Icons.star,
  Icons.eco,
  Icons.cake,
  Icons.anchor,
  Icons.bolt,
  Icons.music_note,
  Icons.wb_sunny,
  Icons.ac_unit,
  Icons.local_florist,
  Icons.directions_car,
  Icons.sports_soccer,
  Icons.umbrella,
  Icons.key,
  Icons.diamond,
  Icons.extension,
];

const _shapeIcons = <IconData>[
  Icons.circle,
  Icons.square,
  Icons.change_history,
  Icons.hexagon,
  Icons.pentagon,
  Icons.star,
];

const _palette = <Color>[
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
];

/// Hinh thu [symbol] (0-17) cua bo [set], ve vua khung [size].
class MemorySymbol extends StatelessWidget {
  const MemorySymbol({
    required this.set,
    required this.symbol,
    required this.size,
    this.color,
    super.key,
  });

  final MemorySet set;
  final int symbol;
  final double size;

  /// Ghi de mau hinh (vd trang tren the mau keo); null = mau theo bo hinh.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    switch (set) {
      case MemorySet.icons:
        return Icon(
          memoryIcons[symbol % memoryIcons.length],
          size: size,
          color: color ?? s.onPrimaryContainer,
        );
      case MemorySet.shapes:
        return Icon(
          _shapeIcons[symbol % _shapeIcons.length],
          size: size,
          color:
              color ??
              _palette[(symbol ~/ _shapeIcons.length) % _palette.length],
        );
      case MemorySet.letters:
        return Text(
          String.fromCharCode(65 + symbol % 26),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            height: 1,
            color: color ?? _palette[symbol % _palette.length],
          ),
        );
    }
  }
}
