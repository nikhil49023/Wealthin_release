import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'data_service.dart'; // For DashboardData

/// PDF Report Generator for Financial Health Analysis
/// Produces professional multi-page reports with AI insights
class PdfReportService {
  static final PdfReportService _instance = PdfReportService._internal();
  factory PdfReportService() => _instance;
  PdfReportService._internal();

  // Design constants
  static const double _margin = 40;
  static const double _lineHeight = 18;
  
  /// Generate a comprehensive Financial Health PDF Report
  Future<String> generateHealthReport({
    required HealthScore healthScore,
    required DashboardData? dashboardData,
    required String userName,
    Map<String, double>? categoryBreakdown,
  }) async {
    final PdfDocument document = PdfDocument();
    document.pageSettings.margins.all = 0;
    
    // Fonts
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 26, style: PdfFontStyle.bold);
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final subHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final bodyBold = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final scoreFont = PdfStandardFont(PdfFontFamily.helvetica, 42, style: PdfFontStyle.bold);
    final gradeFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    
    // Colors
    final primaryColor = PdfColor(16, 185, 129);  // Emerald-500
    final darkColor = PdfColor(6, 78, 59);          // Emerald-900
    final lightBg = PdfColor(240, 253, 244);         // Emerald-50
    final accentColor = PdfColor(245, 158, 11);      // Amber-500
    final warningColor = PdfColor(239, 68, 68);      // Red-500
    
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    // ==================== PAGE 1: OVERVIEW ====================
    PdfPage page = document.pages.add();
    PdfGraphics g = page.graphics;
    final Size ps = page.getClientSize();
    double y = 0;
    
    // --- Header Banner ---
    g.drawRectangle(
      brush: PdfSolidBrush(darkColor),
      bounds: Rect.fromLTWH(0, 0, ps.width, 100),
    );
    // Accent line
    g.drawRectangle(
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, 95, ps.width, 5),
    );
    
    g.drawString(
      'WealthIn Financial Health Report',
      titleFont,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(_margin, 25, ps.width - _margin * 2, 35),
    );
    g.drawString(
      'Prepared for $userName  •  ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}',
      smallFont,
      brush: PdfSolidBrush(PdfColor(167, 243, 208)), // Emerald-200
      bounds: Rect.fromLTWH(_margin, 60, ps.width - _margin * 2, 20),
    );
    
    y = 120;
    
    // --- Health Score Card ---
    // Score box background
    g.drawRectangle(
      brush: PdfSolidBrush(lightBg),
      bounds: Rect.fromLTWH(_margin, y, ps.width - _margin * 2, 90),
    );
    g.drawRectangle(
      pen: PdfPen(primaryColor, width: 1.5),
      bounds: Rect.fromLTWH(_margin, y, ps.width - _margin * 2, 90),
    );
    
    // Score number
    g.drawString(
      healthScore.totalScore.toStringAsFixed(0),
      scoreFont,
      brush: PdfSolidBrush(_getScoreColor(healthScore.totalScore)),
      bounds: Rect.fromLTWH(_margin + 25, y + 15, 100, 55),
    );
    g.drawString(
      '/ 100',
      bodyFont,
      brush: PdfBrushes.gray,
      bounds: Rect.fromLTWH(_margin + 25, y + 60, 60, 20),
    );
    
    // Grade text
    g.drawString(
      healthScore.grade.toUpperCase(),
      gradeFont,
      brush: PdfSolidBrush(_getScoreColor(healthScore.totalScore)),
      bounds: Rect.fromLTWH(_margin + 140, y + 15, 200, 25),
    );
    g.drawString(
      _getScoreDescription(healthScore.totalScore),
      bodyFont,
      brush: PdfBrushes.darkGray,
      bounds: Rect.fromLTWH(_margin + 140, y + 38, ps.width - _margin * 2 - 160, 40),
    );
    
    y += 110;
    
    // --- Score Breakdown ---
    _drawSectionHeader(g, 'Score Breakdown', headerFont, primaryColor, y, ps.width);
    y += 35;
    
    final breakdownItems = [
      {'label': 'Savings', 'score': healthScore.breakdown['savings'] ?? 0, 'max': 30.0, 'icon': '💰'},
      {'label': 'Debt Management', 'score': healthScore.breakdown['debt'] ?? 0, 'max': 25.0, 'icon': '🏦'},
      {'label': 'Liquidity Reserve', 'score': healthScore.breakdown['liquidity'] ?? 0, 'max': 25.0, 'icon': '💧'},
      {'label': 'Investment Progress', 'score': healthScore.breakdown['investment'] ?? 0, 'max': 20.0, 'icon': '📈'},
    ];
    
    for (var item in breakdownItems) {
      final score = item['score'] as double;
      final max = item['max'] as double;
      final label = item['label'] as String;
      final pct = max > 0 ? (score / max * 100) : 0.0;
      
      g.drawString(
        '$label: ${score.toStringAsFixed(1)} / ${max.toStringAsFixed(0)} pts (${pct.toStringAsFixed(0)}%)',
        bodyFont,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(_margin, y, ps.width - _margin * 2, 18),
      );
      
      // Progress bar background
      final barX = _margin;
      final barW = ps.width - _margin * 2;
      g.drawRectangle(
        brush: PdfSolidBrush(PdfColor(229, 231, 235)),
        bounds: Rect.fromLTWH(barX, y + 20, barW, 10),
      );
      // Progress bar fill
      final fillW = barW * (score / max).clamp(0, 1);
      g.drawRectangle(
        brush: PdfSolidBrush(_getBarColor(pct)),
        bounds: Rect.fromLTWH(barX, y + 20, fillW, 10),
      );
      
      y += 42;
    }
    
    y += 10;
    
    // --- Financial Summary ---
    if (dashboardData != null) {
      _drawSectionHeader(g, 'Financial Summary', headerFont, primaryColor, y, ps.width);
      y += 35;
      
      final income = dashboardData.totalIncome;
      final expense = dashboardData.totalExpense;
      final savings = income - expense;
      final savingsRate = dashboardData.savingsRate;
      
      // Summary cards (two columns)
      final colW = (ps.width - _margin * 2 - 20) / 2;
      
      // Card 1: Income
      _drawMetricCard(g, 'Monthly Income', formatter.format(income), primaryColor, _margin, y, colW, 50);
      // Card 2: Expenses
      _drawMetricCard(g, 'Monthly Expenses', formatter.format(expense), warningColor, _margin + colW + 20, y, colW, 50);
      y += 60;
      
      // Card 3: Net Savings
      _drawMetricCard(g, 'Net Savings', formatter.format(savings), savings >= 0 ? primaryColor : warningColor, _margin, y, colW, 50);
      // Card 4: Savings Rate
      _drawMetricCard(g, 'Savings Rate', '${savingsRate.toStringAsFixed(1)}%', savingsRate >= 20 ? primaryColor : accentColor, _margin + colW + 20, y, colW, 50);
      y += 70;
    }
    
    // --- Category Spending Breakdown ---
    if (categoryBreakdown != null && categoryBreakdown.isNotEmpty) {
      if (y > ps.height - 200) {
        _drawFooter(g, ps, smallFont);
        page = document.pages.add();
        g = page.graphics;
        y = _margin;
      }
      
      _drawSectionHeader(g, 'Category-wise Spending', headerFont, primaryColor, y, ps.width);
      y += 35;
      
      final totalSpend = categoryBreakdown.values.fold(0.0, (a, b) => a + b);
      final sorted = categoryBreakdown.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      for (var entry in sorted.take(8)) {
        final pct = totalSpend > 0 ? (entry.value / totalSpend * 100) : 0.0;
        final barW = (ps.width - _margin * 2 - 180);
        
        g.drawString(
          entry.key,
          bodyBold,
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(_margin, y, 120, 18),
        );
        
        // Mini progress bar
        g.drawRectangle(
          brush: PdfSolidBrush(PdfColor(229, 231, 235)),
          bounds: Rect.fromLTWH(_margin + 120, y + 3, barW, 12),
        );
        g.drawRectangle(
          brush: PdfSolidBrush(_getCategoryColor(entry.key)),
          bounds: Rect.fromLTWH(_margin + 120, y + 3, barW * (pct / 100).clamp(0, 1), 12),
        );
        
        g.drawString(
          '${formatter.format(entry.value)} (${pct.toStringAsFixed(1)}%)',
          smallFont,
          brush: PdfBrushes.darkGray,
          bounds: Rect.fromLTWH(_margin + 125 + barW, y + 2, 150, 18),
        );
        
        y += 22;
      }
      
      y += 10;
    }
    
    // --- Insights Section ---
    if (healthScore.insights.isNotEmpty) {
      if (y > ps.height - 150) {
        _drawFooter(g, ps, smallFont);
        page = document.pages.add();
        g = page.graphics;
        y = _margin;
      }
      
      _drawSectionHeader(g, 'Key Insights', headerFont, primaryColor, y, ps.width);
      y += 35;
      
      for (var insight in healthScore.insights) {
        g.drawString(
          '  •  $insight',
          bodyFont,
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(_margin, y, ps.width - _margin * 2, 36),
        );
        y += 28;
      }
      
      y += 10;
    }
    
    _drawFooter(g, ps, smallFont);

    // ==================== PAGE 2: AI ANALYSIS (if available) ====================
    if (healthScore.aiAnalysis != null && healthScore.aiAnalysis!.isNotEmpty) {
      page = document.pages.add();
      g = page.graphics;
      y = 0;
      
      // Header banner for page 2
      g.drawRectangle(
        brush: PdfSolidBrush(darkColor),
        bounds: Rect.fromLTWH(0, 0, ps.width, 65),
      );
      g.drawRectangle(
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(0, 60, ps.width, 5),
      );
      g.drawString(
        'AI-Powered Financial Analysis',
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold),
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(_margin, 20, ps.width - _margin * 2, 30),
      );
      g.drawString(
        'Powered by WealthIn AI (Groq GPT-OSS)',
        smallFont,
        brush: PdfSolidBrush(PdfColor(167, 243, 208)),
        bounds: Rect.fromLTWH(_margin, 44, ps.width - _margin * 2, 16),
      );
      
      y = 80;
      
      // Parse and render the AI analysis text with markdown-like formatting
      final lines = healthScore.aiAnalysis!.split('\n');
      for (var line in lines) {
        if (y > ps.height - 50) {
          _drawFooter(g, ps, smallFont);
          page = document.pages.add();
          g = page.graphics;
          y = _margin;
        }
        
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          y += 8;
          continue;
        }
        
        if (trimmed.startsWith('### ') || trimmed.startsWith('## ')) {
          // Section header
          final text = trimmed.replaceAll(RegExp(r'^#{2,3}\s*'), '');
          y += 6;
          g.drawString(
            text,
            subHeaderFont,
            brush: PdfSolidBrush(darkColor),
            bounds: Rect.fromLTWH(_margin, y, ps.width - _margin * 2, 22),
          );
          y += 24;
          // Underline
          g.drawLine(
            PdfPen(primaryColor, width: 1),
            Offset(_margin, y),
            Offset(ps.width - _margin, y),
          );
          y += 6;
        } else if (trimmed.startsWith('• ') || trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          // Bullet point
          final text = trimmed.replaceAll(RegExp(r'^[•\-\*]\s*'), '');
          g.drawString(
            '  •  $text',
            bodyFont,
            brush: PdfBrushes.black,
            bounds: Rect.fromLTWH(_margin, y, ps.width - _margin * 2, 36),
          );
          y += _estimateLineHeight(text, bodyFont, ps.width - _margin * 2);
        } else if (RegExp(r'^\d+\.').hasMatch(trimmed)) {
          // Numbered list
          g.drawString(
            '  $trimmed',
            bodyFont,
            brush: PdfBrushes.black,
            bounds: Rect.fromLTWH(_margin, y, ps.width - _margin * 2, 36),
          );
          y += _estimateLineHeight(trimmed, bodyFont, ps.width - _margin * 2);
        } else {
          // Regular text (strip markdown bold)
          final text = trimmed.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
          g.drawString(
            text,
            bodyFont,
            brush: PdfBrushes.black,
            bounds: Rect.fromLTWH(_margin, y, ps.width - _margin * 2, 36),
          );
          y += _estimateLineHeight(text, bodyFont, ps.width - _margin * 2);
        }
      }
      
      _drawFooter(g, ps, smallFont);
    }
    
    // Save to file
    final List<int> bytes = await document.save();
    document.dispose();
    
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${directory.path}/WealthIn_Report_$timestamp.pdf';
    
    final File file = File(filePath);
    await file.writeAsBytes(bytes);
    
    return filePath;
  }

  // ==================== Helper Methods ====================
  
  void _drawSectionHeader(PdfGraphics g, String title, PdfFont font, PdfColor color, double y, double pageWidth) {
    g.drawString(
      title,
      font,
      brush: PdfSolidBrush(color),
      bounds: Rect.fromLTWH(_margin, y, pageWidth - _margin * 2, 25),
    );
    g.drawLine(
      PdfPen(color, width: 1),
      Offset(_margin, y + 22),
      Offset(pageWidth - _margin, y + 22),
    );
  }
  
  void _drawMetricCard(PdfGraphics g, String label, String value, PdfColor color, double x, double y, double w, double h) {
    g.drawRectangle(
      brush: PdfSolidBrush(PdfColor(249, 250, 251)),
      bounds: Rect.fromLTWH(x, y, w, h),
    );
    g.drawRectangle(
      pen: PdfPen(PdfColor(229, 231, 235)),
      bounds: Rect.fromLTWH(x, y, w, h),
    );
    // Color accent left border
    g.drawRectangle(
      brush: PdfSolidBrush(color),
      bounds: Rect.fromLTWH(x, y, 4, h),
    );
    
    g.drawString(
      label,
      PdfStandardFont(PdfFontFamily.helvetica, 9),
      brush: PdfBrushes.gray,
      bounds: Rect.fromLTWH(x + 14, y + 8, w - 20, 14),
    );
    g.drawString(
      value,
      PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(color),
      bounds: Rect.fromLTWH(x + 14, y + 24, w - 20, 22),
    );
  }
  
  void _drawFooter(PdfGraphics g, Size ps, PdfFont font) {
    g.drawLine(
      PdfPen(PdfColor(209, 213, 219), width: 0.5),
      Offset(_margin, ps.height - 35),
      Offset(ps.width - _margin, ps.height - 35),
    );
    g.drawString(
      'WealthIn  •  This report is for informational purposes only and does not constitute financial advice.',
      font,
      brush: PdfBrushes.gray,
      bounds: Rect.fromLTWH(_margin, ps.height - 28, ps.width - _margin * 2, 20),
    );
  }
  
  double _estimateLineHeight(String text, PdfFont font, double maxWidth) {
    // Rough estimate: ~7 chars per unit width for helvetica 11pt
    final charsPerLine = (maxWidth / 6.5).floor();
    if (charsPerLine <= 0) return _lineHeight;
    final lines = (text.length / charsPerLine).ceil().clamp(1, 4);
    return (lines * _lineHeight).toDouble();
  }
  
  PdfColor _getScoreColor(double score) {
    if (score >= 80) return PdfColor(16, 185, 129);  // Emerald
    if (score >= 60) return PdfColor(34, 197, 94);    // Green
    if (score >= 40) return PdfColor(245, 158, 11);   // Amber
    if (score >= 20) return PdfColor(249, 115, 22);   // Orange
    return PdfColor(239, 68, 68);                     // Red
  }
  
  PdfColor _getBarColor(double pct) {
    if (pct >= 80) return PdfColor(16, 185, 129);
    if (pct >= 60) return PdfColor(34, 197, 94);
    if (pct >= 40) return PdfColor(245, 158, 11);
    return PdfColor(249, 115, 22);
  }
  
  PdfColor _getCategoryColor(String category) {
    final colors = {
      'Food & Dining': PdfColor(239, 68, 68),
      'Food': PdfColor(239, 68, 68),
      'Transport': PdfColor(59, 130, 246),
      'Transportation': PdfColor(59, 130, 246),
      'Shopping': PdfColor(168, 85, 247),
      'Entertainment': PdfColor(236, 72, 153),
      'Utilities': PdfColor(245, 158, 11),
      'Bills': PdfColor(245, 158, 11),
      'Health': PdfColor(16, 185, 129),
      'Health & Fitness': PdfColor(16, 185, 129),
      'Education': PdfColor(20, 184, 166),
      'Rent': PdfColor(99, 102, 241),
      'Subscriptions': PdfColor(139, 92, 246),
      'Insurance': PdfColor(6, 182, 212),
      'Loan': PdfColor(239, 68, 68),
    };
    return colors[category] ?? PdfColor(107, 114, 128);
  }
  
  String _getScoreDescription(double score) {
    if (score >= 80) return 'Excellent! Your finances are well-managed with strong savings and low debt.';
    if (score >= 65) return 'Good financial health. A few areas can be optimized for better results.';
    if (score >= 45) return 'Fair. Focus on building savings and reducing high-interest debt.';
    return 'Needs improvement. Prioritize budgeting and building an emergency fund.';
  }
}

final pdfReportService = PdfReportService();
