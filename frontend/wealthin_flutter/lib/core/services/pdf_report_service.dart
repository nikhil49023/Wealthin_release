import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'data_service.dart'; // For DashboardData

/// PDF Report Generator for Financial Health Analysis
/// Clean, minimal, feel-good design with betterment paths
class PdfReportService {
  static final PdfReportService _instance = PdfReportService._internal();
  factory PdfReportService() => _instance;
  PdfReportService._internal();

  // Design constants
  static const double _m = 44; // Margin
  static const double _lh = 17; // Line height

  /// Generate a comprehensive Financial Health PDF Report
  Future<String> generateHealthReport({
    required HealthScore healthScore,
    required DashboardData? dashboardData,
    required String userName,
    Map<String, double>? categoryBreakdown,
  }) async {
    final PdfDocument doc = PdfDocument();
    doc.pageSettings.margins.all = 0;

    // — Typography —
    final fTitle = PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold);
    final fH1 = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final fH2 = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final fBody = PdfStandardFont(PdfFontFamily.helvetica, 10.5);
    final fBold = PdfStandardFont(PdfFontFamily.helvetica, 10.5, style: PdfFontStyle.bold);
    final fSmall = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final fScore = PdfStandardFont(PdfFontFamily.helvetica, 44, style: PdfFontStyle.bold);
    final fGrade = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);

    // — Soft, Minimalist Palette —
    final cDark = PdfColor(30, 41, 59);        // Slate-800
    final cPrimary = PdfColor(16, 185, 129);    // Emerald-500
    final cPrimaryL = PdfColor(209, 250, 229);  // Emerald-100
    final cBg = PdfColor(248, 250, 252);        // Slate-50
    final cWarm = PdfColor(251, 191, 36);       // Amber-400
    final cRed = PdfColor(239, 68, 68);         // Red-500
    final cSubtle = PdfColor(148, 163, 184);    // Slate-400
    final cLine = PdfColor(226, 232, 240);      // Slate-200

    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final score = healthScore.totalScore.isNaN ? 0.0 : healthScore.totalScore;

    // ======================================
    // PAGE 1: Cover + Overview
    // ======================================
    PdfPage pg = doc.pages.add();
    PdfGraphics g = pg.graphics;
    final Size ps = pg.getClientSize();
    double y = 0;

    // — Header —
    g.drawRectangle(brush: PdfSolidBrush(cDark), bounds: Rect.fromLTWH(0, 0, ps.width, 90));
    g.drawRectangle(brush: PdfSolidBrush(cPrimary), bounds: Rect.fromLTWH(0, 87, ps.width, 3));
    g.drawString('Financial Health Report', fTitle, brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(_m, 22, ps.width - _m * 2, 30));
    g.drawString(
      'Prepared for $userName  •  ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
      fSmall, brush: PdfSolidBrush(PdfColor(167, 243, 208)),
      bounds: Rect.fromLTWH(_m, 55, ps.width - _m * 2, 18));
    y = 108;

    // — Score Card —
    _drawRoundedRect(g, _m, y, ps.width - _m * 2, 90, cBg, cLine);
    g.drawString(score.toStringAsFixed(0), fScore,
      brush: PdfSolidBrush(_scoreColor(score)),
      bounds: Rect.fromLTWH(_m + 24, y + 14, 90, 55));
    g.drawString('/ 100', fSmall, brush: PdfSolidBrush(cSubtle),
      bounds: Rect.fromLTWH(_m + 24, y + 62, 50, 14));
    g.drawString(healthScore.grade.toUpperCase(), fGrade,
      brush: PdfSolidBrush(_scoreColor(score)),
      bounds: Rect.fromLTWH(_m + 140, y + 14, 200, 22));
    g.drawString(_gradeMessage(score), fBody, brush: PdfSolidBrush(cDark),
      bounds: Rect.fromLTWH(_m + 140, y + 38, ps.width - _m * 2 - 160, 40));
    y += 106;

    // — Score Breakdown (Pass/Fail style) —
    _sectionHead(g, 'Score Breakdown', fH1, cPrimary, y, ps.width);
    y += 32;

    final pillars = [
      _Pillar('Savings Rate', healthScore.breakdown['savings'] ?? 0, 30, 'Save 20%+ of income to boost this pillar'),
      _Pillar('Debt Management', healthScore.breakdown['debt'] ?? 0, 25, 'Keep total EMIs below 35% of income'),
      _Pillar('Emergency Fund', healthScore.breakdown['liquidity'] ?? 0, 25, 'Target: 6 months of expenses saved'),
      _Pillar('Goal Progress', healthScore.breakdown['investment'] ?? 0, 20, 'Consistent SIP/RD improves this'),
    ];

    for (final p in pillars) {
      final pct = p.max > 0 ? (p.score / p.max).clamp(0.0, 1.0) : 0.0;
      final passed = pct >= 0.5;
      final barColor = passed ? cPrimary : (pct >= 0.25 ? cWarm : cRed);

      // Status indicator + label
      g.drawString(passed ? '✓' : '!', fBold,
        brush: PdfSolidBrush(barColor),
        bounds: Rect.fromLTWH(_m, y, 14, 16));
      g.drawString(p.name, fBold, brush: PdfSolidBrush(cDark),
        bounds: Rect.fromLTWH(_m + 18, y, 160, 16));
      g.drawString(passed ? 'Passed' : 'Needs Work', fSmall,
        brush: PdfSolidBrush(barColor),
        bounds: Rect.fromLTWH(ps.width - _m - 70, y, 70, 14),
        format: PdfStringFormat(alignment: PdfTextAlignment.right));
      y += 16;

      // Progress bar
      g.drawRectangle(brush: PdfSolidBrush(cLine),
        bounds: Rect.fromLTWH(_m + 18, y, ps.width - _m * 2 - 100, 7));
      g.drawRectangle(brush: PdfSolidBrush(barColor),
        bounds: Rect.fromLTWH(_m + 18, y, (ps.width - _m * 2 - 100) * pct, 7));
      g.drawString('${p.score.toStringAsFixed(0)}/${p.max.toStringAsFixed(0)}', fSmall,
        brush: PdfSolidBrush(barColor),
        bounds: Rect.fromLTWH(ps.width - _m - 70, y - 1, 70, 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.right));
      y += 11;

      // Tip
      g.drawString(p.tip, fSmall, brush: PdfSolidBrush(cSubtle),
        bounds: Rect.fromLTWH(_m + 18, y, ps.width - _m * 2 - 20, 12));
      y += 20;
    }

    y += 8;

    // — Financial Summary —
    if (dashboardData != null) {
      _sectionHead(g, 'Monthly Snapshot', fH1, cPrimary, y, ps.width);
      y += 32;

      final inc = dashboardData.totalIncome;
      final exp = dashboardData.totalExpense;
      final sav = inc - exp;
      final sr = dashboardData.savingsRate;
      final colW = (ps.width - _m * 2 - 16) / 2;

      _metricCard(g, 'Income', fmt.format(inc), cPrimary, _m, y, colW, 44);
      _metricCard(g, 'Expenses', fmt.format(exp), cRed, _m + colW + 16, y, colW, 44);
      y += 52;
      _metricCard(g, 'Net Savings', fmt.format(sav), sav >= 0 ? cPrimary : cRed, _m, y, colW, 44);
      _metricCard(g, 'Savings Rate', '${sr.toStringAsFixed(1)}%', sr >= 20 ? cPrimary : cWarm, _m + colW + 16, y, colW, 44);
      y += 56;
    }

    // — Category Spending —
    if (categoryBreakdown != null && categoryBreakdown.isNotEmpty) {
      if (y > ps.height - 180) { _footer(g, ps, fSmall); pg = doc.pages.add(); g = pg.graphics; y = _m; }

      _sectionHead(g, 'Where Your Money Goes', fH1, cPrimary, y, ps.width);
      y += 30;

      final total = categoryBreakdown.values.fold(0.0, (a, b) => a + b);
      final sorted = categoryBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      for (var e in sorted.take(8)) {
        final pct = total > 0 ? (e.value / total * 100) : 0.0;
        final bw = ps.width - _m * 2 - 170;

        g.drawString(e.key, fBold, brush: PdfSolidBrush(cDark),
          bounds: Rect.fromLTWH(_m, y, 110, 16));
        g.drawRectangle(brush: PdfSolidBrush(cLine),
          bounds: Rect.fromLTWH(_m + 112, y + 3, bw, 10));
        g.drawRectangle(brush: PdfSolidBrush(_catColor(e.key)),
          bounds: Rect.fromLTWH(_m + 112, y + 3, bw * (pct / 100).clamp(0, 1), 10));
        g.drawString('${fmt.format(e.value)} (${pct.toStringAsFixed(0)}%)', fSmall,
          brush: PdfSolidBrush(cSubtle),
          bounds: Rect.fromLTWH(_m + 116 + bw, y + 2, 140, 14));
        y += 20;
      }
      y += 8;
    }

    // — Insights —
    if (healthScore.insights.isNotEmpty) {
      if (y > ps.height - 120) { _footer(g, ps, fSmall); pg = doc.pages.add(); g = pg.graphics; y = _m; }

      _sectionHead(g, 'Key Insights', fH1, cPrimary, y, ps.width);
      y += 28;
      for (var ins in healthScore.insights) {
        g.drawString('  •  $ins', fBody, brush: PdfSolidBrush(cDark),
          bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 32));
        y += _lineH(ins, fBody, ps.width - _m * 2);
      }
    }

    _footer(g, ps, fSmall);

    // ======================================
    // PAGE 2: How Your Score Works
    // ======================================
    pg = doc.pages.add(); g = pg.graphics; y = 0;

    _pageHeader(g, ps, 'How Your Score Works', 'Transparent 4-Pillar Methodology', cDark, cPrimary, fSmall);
    y = 78;

    g.drawString(
      'Your WealthIn Health Score measures four pillars of financial wellness, each weighted by its importance to long-term stability. Here\'s exactly how each one is calculated with your numbers.',
      fBody, brush: PdfSolidBrush(cDark),
      bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 42));
    y += 46;

    final pillarDetails = [
      {'name': 'Savings (30 pts)', 'score': healthScore.breakdown['savings'] ?? 0, 'max': 30.0,
       'how': 'Your savings rate × 30. ${dashboardData != null ? "Your rate: ${dashboardData.savingsRate.toStringAsFixed(1)}%." : ""}',
       'improve': 'Set up auto-transfer of 10% of salary to a savings account on payday. Even ₹500/month extra compounds significantly over a year.'},
      {'name': 'Debt (25 pts)', 'score': healthScore.breakdown['debt'] ?? 0, 'max': 25.0,
       'how': '(1 − Debt-to-Income ratio) × 25. Below 35% is healthy, below 20% is excellent.',
       'improve': 'Pay off highest-interest debt first (credit cards → personal loans → home loans). Avoid new EMIs until existing ones drop below 30% of income.'},
      {'name': 'Liquidity (25 pts)', 'score': healthScore.breakdown['liquidity'] ?? 0, 'max': 25.0,
       'how': '(Emergency fund months ÷ 6) × 25. Goal: 6 months of essential expenses saved.',
       'improve': 'Start a liquid mutual fund or high-yield savings account. Target ₹${dashboardData != null ? fmt.format(dashboardData.totalExpense * 6) : "X"} as your emergency buffer.'},
      {'name': 'Goals (20 pts)', 'score': healthScore.breakdown['investment'] ?? 0, 'max': 20.0,
       'how': '(Amount saved toward goals ÷ Goal target) × 20.',
       'improve': 'Set specific, time-bound goals and invest via SIP or RD. Even ₹1,000/month SIP grows to ₹2.1L in 10 years at 12% returns.'},
    ];

    for (var pd in pillarDetails) {
      if (y > ps.height - 120) { _footer(g, ps, fSmall); pg = doc.pages.add(); g = pg.graphics; y = _m; }

      final sc = pd['score'] as double;
      final mx = pd['max'] as double;
      final pct = mx > 0 ? (sc / mx * 100) : 0.0;

      // Pillar header
      g.drawString(pd['name'] as String, fH2, brush: PdfSolidBrush(cDark),
        bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2 - 80, 18));
      g.drawString('${sc.toStringAsFixed(1)} / ${mx.toStringAsFixed(0)}', fBold,
        brush: PdfSolidBrush(_barColor(pct)),
        bounds: Rect.fromLTWH(ps.width - _m - 70, y, 70, 16),
        format: PdfStringFormat(alignment: PdfTextAlignment.right));
      y += 20;

      // Bar
      g.drawRectangle(brush: PdfSolidBrush(cLine),
        bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 8));
      g.drawRectangle(brush: PdfSolidBrush(_barColor(pct)),
        bounds: Rect.fromLTWH(_m, y, (ps.width - _m * 2) * (sc / mx).clamp(0, 1), 8));
      y += 14;

      // How it works
      g.drawString('How: ${pd['how']}', fSmall, brush: PdfSolidBrush(cSubtle),
        bounds: Rect.fromLTWH(_m + 8, y, ps.width - _m * 2 - 16, 28));
      y += 22;

      // Improvement box
      _drawRoundedRect(g, _m + 8, y, ps.width - _m * 2 - 16, 24, cPrimaryL, PdfColor(167, 243, 208));
      g.drawString('→ ${pd['improve']}', fSmall, brush: PdfSolidBrush(PdfColor(6, 95, 70)),
        bounds: Rect.fromLTWH(_m + 14, y + 5, ps.width - _m * 2 - 30, 18));
      y += 34;
    }

    // Grade tiers
    if (y > ps.height - 100) { _footer(g, ps, fSmall); pg = doc.pages.add(); g = pg.graphics; y = _m; }
    y += 6;
    _sectionHead(g, 'Your Path Forward', fH1, cPrimary, y, ps.width);
    y += 28;

    final tiers = [
      {'range': '80–100', 'grade': 'Excellent', 'lo': 80.0, 'hi': 100.0, 'c': cPrimary},
      {'range': '65–79', 'grade': 'Good', 'lo': 65.0, 'hi': 79.0, 'c': PdfColor(34, 197, 94)},
      {'range': '45–64', 'grade': 'Fair', 'lo': 45.0, 'hi': 64.0, 'c': cWarm},
      {'range': '0–44', 'grade': 'Needs Work', 'lo': 0.0, 'hi': 44.0, 'c': cRed},
    ];

    for (var t in tiers) {
      final isCurrent = score >= (t['lo'] as double) && score <= (t['hi'] as double);
      if (isCurrent) {
        _drawRoundedRect(g, _m, y - 2, ps.width - _m * 2, 20, cPrimaryL, PdfColor(167, 243, 208));
      }
      g.drawRectangle(brush: PdfSolidBrush(t['c'] as PdfColor),
        bounds: Rect.fromLTWH(_m + 6, y + 2, 10, 10));
      g.drawString(
        '${t['range']}  —  ${t['grade']}${isCurrent ? '  ← You are here' : ''}',
        isCurrent ? fBold : fBody,
        brush: PdfSolidBrush(isCurrent ? cDark : cSubtle),
        bounds: Rect.fromLTWH(_m + 22, y, ps.width - _m * 2, 16));
      y += 20;
    }

    _footer(g, ps, fSmall);

    // ======================================
    // PAGE 3+: AI Analysis
    // ======================================
    if (healthScore.aiAnalysis != null && healthScore.aiAnalysis!.isNotEmpty) {
      pg = doc.pages.add(); g = pg.graphics; y = 0;

      _pageHeader(g, ps, 'AI-Powered Analysis', 'Personalized insights from WealthIn AI', cDark, cPrimary, fSmall);
      y = 78;

      final lines = healthScore.aiAnalysis!.split('\n');
      for (var line in lines) {
        // Page break if near bottom
        if (y > ps.height - 50) {
          _footer(g, ps, fSmall);
          pg = doc.pages.add(); g = pg.graphics; y = _m;
        }

        final tr = line.trim();
        if (tr.isEmpty) { y += 6; continue; }

        // Skip markdown table separators
        if (RegExp(r'^\|[\s\-:]+\|').hasMatch(tr)) continue;

        // — Section headers (### or ##) —
        if (tr.startsWith('### ') || tr.startsWith('## ')) {
          final text = tr.replaceAll(RegExp(r'^#{2,3}\s*'), '');
          y += 8;
          g.drawString(text, fH2, brush: PdfSolidBrush(cDark),
            bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 20));
          y += 22;
          g.drawLine(PdfPen(cPrimary, width: 1), Offset(_m, y), Offset(_m + 80, y));
          y += 6;
        }
        // — Bold sub-headers (**Month 1:** etc) —
        else if (tr.startsWith('**') && tr.contains('**') && tr.indexOf('**', 2) < tr.length - 2) {
          final text = tr.replaceAll('**', '');
          y += 4;
          g.drawString(text, fBold, brush: PdfSolidBrush(cDark),
            bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 16));
          y += 18;
        }
        // — Markdown table rows —
        else if (tr.startsWith('|') && tr.endsWith('|')) {
          final cells = tr.split('|').where((c) => c.trim().isNotEmpty)
            .map((c) => c.trim().replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1')).toList();
          if (cells.isNotEmpty) {
            g.drawString(cells.join('  •  '), fSmall, brush: PdfSolidBrush(cDark),
              bounds: Rect.fromLTWH(_m + 4, y, ps.width - _m * 2 - 8, 16));
            y += 15;
          }
        }
        // — Bullet points —
        else if (tr.startsWith('• ') || tr.startsWith('- ') || tr.startsWith('* ') || tr.startsWith('→ ')) {
          final text = tr.replaceAll(RegExp(r'^[•\-\*→]\s*'), '')
            .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
          g.drawString('  •  $text', fBody, brush: PdfSolidBrush(cDark),
            bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 32));
          y += _lineH(text, fBody, ps.width - _m * 2);
        }
        // — Numbered steps —
        else if (RegExp(r'^\d+\.').hasMatch(tr)) {
          final text = tr.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
          g.drawString('  $text', fBody, brush: PdfSolidBrush(cDark),
            bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 32));
          y += _lineH(text, fBody, ps.width - _m * 2);
        }
        // — Full bold line —
        else if (tr.startsWith('**') && tr.endsWith('**')) {
          final text = tr.replaceAll('**', '');
          g.drawString(text, fBold, brush: PdfSolidBrush(cDark),
            bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 18));
          y += 18;
        }
        // — Regular text —
        else {
          final text = tr.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
          g.drawString(text, fBody, brush: PdfSolidBrush(cDark),
            bounds: Rect.fromLTWH(_m, y, ps.width - _m * 2, 32));
          y += _lineH(text, fBody, ps.width - _m * 2);
        }
      }

      _footer(g, ps, fSmall);
    }

    // — Save —
    final bytes = await doc.save();
    doc.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${dir.path}/WealthIn_Report_$ts.pdf';
    await File(path).writeAsBytes(bytes);

    return path;
  }

  // ==================== Helpers ====================

  void _pageHeader(PdfGraphics g, Size ps, String title, String sub,
      PdfColor dark, PdfColor primary, PdfFont smallFont) {
    g.drawRectangle(brush: PdfSolidBrush(dark), bounds: Rect.fromLTWH(0, 0, ps.width, 62));
    g.drawRectangle(brush: PdfSolidBrush(primary), bounds: Rect.fromLTWH(0, 59, ps.width, 3));
    g.drawString(title,
      PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold),
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(_m, 16, ps.width - _m * 2, 24));
    g.drawString(sub, smallFont,
      brush: PdfSolidBrush(PdfColor(167, 243, 208)),
      bounds: Rect.fromLTWH(_m, 40, ps.width - _m * 2, 14));
  }

  void _sectionHead(PdfGraphics g, String title, PdfFont font, PdfColor color, double y, double pw) {
    g.drawString(title, font, brush: PdfSolidBrush(color),
      bounds: Rect.fromLTWH(_m, y, pw - _m * 2, 22));
    g.drawLine(PdfPen(color, width: 1), Offset(_m, y + 20), Offset(pw - _m, y + 20));
  }

  void _metricCard(PdfGraphics g, String label, String value, PdfColor color,
      double x, double y, double w, double h) {
    _drawRoundedRect(g, x, y, w, h, PdfColor(249, 250, 251), PdfColor(226, 232, 240));
    g.drawRectangle(brush: PdfSolidBrush(color), bounds: Rect.fromLTWH(x, y, 3, h));
    g.drawString(label, PdfStandardFont(PdfFontFamily.helvetica, 8.5),
      brush: PdfSolidBrush(PdfColor(148, 163, 184)),
      bounds: Rect.fromLTWH(x + 12, y + 6, w - 16, 12));
    g.drawString(value, PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(color),
      bounds: Rect.fromLTWH(x + 12, y + 20, w - 16, 20));
  }

  void _drawRoundedRect(PdfGraphics g, double x, double y, double w, double h,
      PdfColor fill, PdfColor border) {
    g.drawRectangle(brush: PdfSolidBrush(fill), bounds: Rect.fromLTWH(x, y, w, h));
    g.drawRectangle(pen: PdfPen(border, width: 0.5), bounds: Rect.fromLTWH(x, y, w, h));
  }

  void _footer(PdfGraphics g, Size ps, PdfFont font) {
    g.drawLine(PdfPen(PdfColor(226, 232, 240), width: 0.5),
      Offset(_m, ps.height - 32), Offset(ps.width - _m, ps.height - 32));
    g.drawString(
      'WealthIn  •  Your finances, your growth. This report does not constitute financial advice.',
      font, brush: PdfSolidBrush(PdfColor(148, 163, 184)),
      bounds: Rect.fromLTWH(_m, ps.height - 26, ps.width - _m * 2, 16));
  }

  double _lineH(String text, PdfFont font, double maxW) {
    final cpl = (maxW / 6.2).floor();
    if (cpl <= 0) return _lh;
    final lines = (text.length / cpl).ceil().clamp(1, 4);
    return (lines * _lh).toDouble();
  }

  PdfColor _scoreColor(double s) {
    if (s >= 80) return PdfColor(16, 185, 129);
    if (s >= 60) return PdfColor(34, 197, 94);
    if (s >= 40) return PdfColor(251, 191, 36);
    return PdfColor(239, 68, 68);
  }

  PdfColor _barColor(double pct) {
    if (pct >= 70) return PdfColor(16, 185, 129);
    if (pct >= 40) return PdfColor(251, 191, 36);
    return PdfColor(249, 115, 22);
  }

  String _gradeMessage(double s) {
    if (s >= 80) return 'Excellent! You\'re managing your finances well. Keep going!';
    if (s >= 65) return 'Good progress! A few tweaks can take you further.';
    if (s >= 45) return 'You\'re on the right track. Let\'s focus on key improvements.';
    return 'Every journey has a start. Small steps lead to big wins!';
  }

  PdfColor _catColor(String cat) {
    final m = {
      'Food & Dining': PdfColor(239, 68, 68), 'Food': PdfColor(239, 68, 68),
      'Transport': PdfColor(59, 130, 246), 'Transportation': PdfColor(59, 130, 246),
      'Shopping': PdfColor(168, 85, 247), 'Entertainment': PdfColor(236, 72, 153),
      'Utilities': PdfColor(245, 158, 11), 'Bills': PdfColor(245, 158, 11),
      'Health': PdfColor(16, 185, 129), 'Education': PdfColor(20, 184, 166),
      'Rent': PdfColor(99, 102, 241), 'Subscriptions': PdfColor(139, 92, 246),
      'Insurance': PdfColor(6, 182, 212), 'Loan': PdfColor(239, 68, 68),
    };
    return m[cat] ?? PdfColor(107, 114, 128);
  }
}

class _Pillar {
  final String name;
  final double score;
  final double max;
  final String tip;
  _Pillar(this.name, this.score, this.max, this.tip);
}

final pdfReportService = PdfReportService();
