import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/constants/app_colors.dart';

/// Premium CHI (Cattle Health Index) Score Display Widget
/// Shows a gauge meter, component breakdown, AI observations, and recommendations.
class ChiScoreDisplay extends StatelessWidget {
  final Map<String, dynamic> chiData;

  const ChiScoreDisplay({super.key, required this.chiData});

  @override
  Widget build(BuildContext context) {
    final chiScore = (chiData['chi_score'] as num?)?.toInt() ?? 0;
    final riskCategory = chiData['risk_category'] as String? ?? 'Unknown';
    final riskColor = _parseColor(chiData['risk_color'] as String? ?? '#9E9E9E');
    final bcs = chiData['bcs'] as Map<String, dynamic>? ?? {};
    final components = chiData['components'] as Map<String, dynamic>? ?? {};
    final observations = chiData['observations'] as List? ?? [];
    final recommendations = chiData['recommendations'] as List? ?? [];
    final insurable = chiData['insurable'] as bool? ?? false;
    final insurability = chiData['insurability'] as String? ?? '';
    final recommendedSum = (chiData['recommended_sum_insured'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── CHI Gauge Meter ───────────────────────────────────────
        _ChiGaugeMeter(score: chiScore, riskCategory: riskCategory, riskColor: riskColor),

        const SizedBox(height: 24),

        // ─── Insurability Badge ────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: insurable
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: insurable
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                insurable ? Icons.verified : Icons.cancel,
                color: insurable ? Colors.green[700] : Colors.red[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insurability,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: insurable ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                    if (recommendedSum > 0)
                      Text(
                        'Recommended Sum Insured: Rs ${_formatNumber(recommendedSum)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── BCS Score ─────────────────────────────────────────────
        _SectionTitle(icon: Icons.fitness_center, title: 'Body Condition Score'),
        const SizedBox(height: 8),
        _BcsBar(
          score: (bcs['score'] as num?)?.toDouble() ?? 0,
          category: bcs['category'] as String? ?? 'Unknown',
          concern: bcs['concern'] as String? ?? '',
        ),

        const SizedBox(height: 24),

        // ─── Component Breakdown ───────────────────────────────────
        _SectionTitle(icon: Icons.analytics, title: 'Health Components'),
        const SizedBox(height: 8),
        ...components.entries.map((entry) {
          final name = entry.key.replaceAll('_', ' ');
          final comp = entry.value as Map<String, dynamic>;
          final score = (comp['score'] as num?)?.toInt() ?? 0;
          final weight = (comp['weight'] as num?)?.toDouble() ?? 0;
          return _ComponentBar(
            name: _capitalize(name),
            score: score,
            weight: weight,
          );
        }),

        const SizedBox(height: 24),

        // ─── AI Observations ───────────────────────────────────────
        _SectionTitle(icon: Icons.psychology, title: 'AI Health Observations'),
        const SizedBox(height: 8),
        ...observations.map((obs) {
          final o = obs as Map<String, dynamic>;
          return _ObservationCard(
            category: o['category'] as String? ?? '',
            text: o['text'] as String? ?? '',
            severity: o['severity'] as String? ?? 'info',
            color: _parseColor(o['color'] as String? ?? '#546E7A'),
          );
        }),

        const SizedBox(height: 24),

        // ─── AI Recommendations ────────────────────────────────────
        _SectionTitle(icon: Icons.lightbulb, title: 'Recommendations'),
        const SizedBox(height: 8),
        ...recommendations.map((rec) {
          final r = rec as Map<String, dynamic>;
          return _RecommendationCard(
            priority: r['priority'] as String? ?? 'Low',
            text: r['text'] as String? ?? '',
            color: _parseColor(r['color'] as String? ?? '#2E7D32'),
          );
        }),

        const SizedBox(height: 16),

        // ─── Model Info ────────────────────────────────────────────
        Center(
          child: Text(
            'Model: ${chiData['model'] ?? 'CHI-v1.0'} • ${chiData['photos_analyzed'] ?? 0} photos analyzed',
            style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  String _formatNumber(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ─── CHI Gauge Meter Widget ─────────────────────────────────────────
class _ChiGaugeMeter extends StatelessWidget {
  final int score;
  final String riskCategory;
  final Color riskColor;

  const _ChiGaugeMeter({
    required this.score,
    required this.riskCategory,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Cattle Health Index',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 120,
            child: CustomPaint(
              painter: _GaugePainter(
                score: score / 100.0,
                riskColor: riskColor,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: GoogleFonts.poppins(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: riskColor,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/ 100',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$riskCategory Risk',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: riskColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Color legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: const Color(0xFFB71C1C), label: '0-39'),
              _LegendDot(color: const Color(0xFFE65100), label: '40-59'),
              _LegendDot(color: const Color(0xFFF57F17), label: '60-79'),
              _LegendDot(color: const Color(0xFF2E7D32), label: '80-100'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ─── Gauge Painter ──────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double score;
  final Color riskColor;

  _GaugePainter({required this.score, required this.riskColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Color gradient segments
    final segments = [
      (const Color(0xFFB71C1C), 0.0, 0.4),
      (const Color(0xFFE65100), 0.4, 0.6),
      (const Color(0xFFF57F17), 0.6, 0.8),
      (const Color(0xFF2E7D32), 0.8, 1.0),
    ];

    for (final (color, start, end) in segments) {
      final segPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + sweepAngle * start,
        sweepAngle * (end - start),
        false,
        segPaint,
      );
    }

    // Score arc
    final scorePaint = Paint()
      ..color = riskColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * score.clamp(0.0, 1.0),
      false,
      scorePaint,
    );

    // Needle dot
    final needleAngle = startAngle + sweepAngle * score.clamp(0.0, 1.0);
    final needleX = center.dx + radius * math.cos(needleAngle);
    final needleY = center.dy + radius * math.sin(needleAngle);
    canvas.drawCircle(
      Offset(needleX, needleY),
      6,
      Paint()..color = riskColor,
    );
    canvas.drawCircle(
      Offset(needleX, needleY),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.score != score || old.riskColor != riskColor;
}

// ─── BCS Bar ────────────────────────────────────────────────────────
class _BcsBar extends StatelessWidget {
  final double score;
  final String category;
  final String concern;

  const _BcsBar({required this.score, required this.category, required this.concern});

  @override
  Widget build(BuildContext context) {
    final color = score >= 2.5 && score <= 3.5
        ? Colors.green
        : score < 2.5
            ? Colors.red
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${score.toStringAsFixed(1)} / 5.0',
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // BCS bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 5.0,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['1', '2', '3', '4', '5']
                .map((l) => Text(l, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey[400])))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            concern,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ─── Component Bar ──────────────────────────────────────────────────
class _ComponentBar extends StatelessWidget {
  final String name;
  final int score;
  final double weight;

  const _ComponentBar({required this.name, required this.score, required this.weight});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              name,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100.0,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 35,
            child: Text(
              '$score%',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Title ──────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}

// ─── Observation Card ───────────────────────────────────────────────
class _ObservationCard extends StatelessWidget {
  final String category;
  final String text;
  final String severity;
  final Color color;

  const _ObservationCard({
    required this.category,
    required this.text,
    required this.severity,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            severity == 'warning' ? Icons.warning_amber : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1A1A2E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recommendation Card ────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  final String priority;
  final String text;
  final Color color;

  const _RecommendationCard({
    required this.priority,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              priority,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1A1A2E)),
            ),
          ),
        ],
      ),
    );
  }
}
