import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'data_service.dart'; // For DashboardData

/// PDF Report Generator for Financial Health Analysis
class PdfReportService {
  static final PdfReportService _instance = PdfReportService._internal();
  factory PdfReportService() => _instance;
  PdfReportService._internal();

  /// Generate a comprehensive Financial Health PDF Report
  Future<String> generateHealthReport({
    required HealthScore healthScore,
    required DashboardData? dashboardData,
    required String userName,
  }) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    final PdfGraphics graphics = page.graphics;
    
    final Size pageSize = page.getClientSize();
    double yOffset = 0;
    
    // Fonts
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 24, style: PdfFontStyle.bold);
    final PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    
    // Colors
    final PdfColor primaryColor = PdfColor(4, 99, 7); // Emerald green
    final PdfColor accentColor = PdfColor(255, 193, 7); // Gold
    
    // Header Section
    graphics.drawRectangle(
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, 0, pageSize.width, 80),
    );
    
    graphics.drawString(
      'WealthIn Financial Health Report',
      titleFont,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(20, 20, pageSize.width - 40, 40),
    );
    
    graphics.drawString(
      'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      smallFont,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(20, 50, pageSize.width - 40, 20),
    );
    
    yOffset = 100;
    
    // User & Score Section
    graphics.drawString(
      'Hello, $userName',
      headerFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(20, yOffset, pageSize.width - 40, 30),
    );
    yOffset += 40;
    
    // Score Circle (simplified as text)
    graphics.drawRectangle(
      pen: PdfPen(primaryColor, width: 2),
      bounds: Rect.fromLTWH(20, yOffset, 120, 60),
    );
    graphics.drawString(
      healthScore.totalScore.toStringAsFixed(0),
      PdfStandardFont(PdfFontFamily.helvetica, 32, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(_getScoreColor(healthScore.totalScore)),
      bounds: Rect.fromLTWH(40, yOffset + 10, 80, 40),
    );
    
    graphics.drawString(
      'Financial Health Score: ${healthScore.grade}',
      headerFont,
      brush: PdfBrushes.black,
      bounds: Rect.fromLTWH(160, yOffset + 15, pageSize.width - 180, 30),
    );
    yOffset += 80;
    
    // Breakdown Section
    graphics.drawString(
      'Score Breakdown',
      headerFont,
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(20, yOffset, pageSize.width - 40, 25),
    );
    yOffset += 35;
    
    final breakdownItems = [
      {'label': 'Savings (30%)', 'score': healthScore.breakdown['savings'] ?? 0, 'max': 30.0},
      {'label': 'Debt Management (30%)', 'score': healthScore.breakdown['debt'] ?? 0, 'max': 30.0},
      {'label': 'Liquidity (20%)', 'score': healthScore.breakdown['liquidity'] ?? 0, 'max': 20.0},
      {'label': 'Investment Diversity (20%)', 'score': healthScore.breakdown['investment'] ?? 0, 'max': 20.0},
    ];
    
    for (var item in breakdownItems) {
      final score = item['score'] as double;
      final max = item['max'] as double;
      final label = item['label'] as String;
      
      graphics.drawString(
        '$label: ${score.toStringAsFixed(1)} / $max pts',
        bodyFont,
        brush: PdfBrushes.black,
        bounds: Rect.fromLTWH(20, yOffset, pageSize.width - 40, 20),
      );
      
      // Progress bar
      final barWidth = (pageSize.width - 60) * (score / max);
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(230, 230, 230)),
        bounds: Rect.fromLTWH(20, yOffset + 20, pageSize.width - 60, 8),
      );
      graphics.drawRectangle(
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(20, yOffset + 20, barWidth, 8),
      );
      yOffset += 40;
    }
    
    yOffset += 10;
    
    // Insights Section
    if (healthScore.insights.isNotEmpty) {
      graphics.drawString(
        'AI Insights & Recommendations',
        headerFont,
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(20, yOffset, pageSize.width - 40, 25),
      );
      yOffset += 35;
      
      for (var insight in healthScore.insights) {
        graphics.drawString(
          '• $insight',
          bodyFont,
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(20, yOffset, pageSize.width - 40, 40),
        );
        yOffset += 25;
      }
    }
    
    yOffset += 20;
    
    // Financial Summary
    if (dashboardData != null) {
      graphics.drawString(
        'Financial Summary',
        headerFont,
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(20, yOffset, pageSize.width - 40, 25),
      );
      yOffset += 35;
      
      final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
      final summaryItems = [
        'Total Income: ${formatter.format(dashboardData.totalIncome)}',
        'Total Expenses: ${formatter.format(dashboardData.totalExpense)}',
        'Net Savings: ${formatter.format(dashboardData.totalIncome - dashboardData.totalExpense)}',
        'Savings Rate: ${dashboardData.savingsRate.toStringAsFixed(1)}%',
      ];
      
      for (var item in summaryItems) {
        graphics.drawString(
          item,
          bodyFont,
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(20, yOffset, pageSize.width - 40, 20),
        );
        yOffset += 22;
      }
    }
    
    // Footer
    graphics.drawString(
      'This report is for informational purposes only. WealthIn does not provide financial advice.',
      smallFont,
      brush: PdfBrushes.gray,
      bounds: Rect.fromLTWH(20, pageSize.height - 30, pageSize.width - 40, 20),
    );
    
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
  
  PdfColor _getScoreColor(double score) {
    if (score >= 80) return PdfColor(76, 175, 80);  // Green
    if (score >= 60) return PdfColor(205, 220, 57); // Lime
    if (score >= 40) return PdfColor(255, 193, 7);  // Amber
    if (score >= 20) return PdfColor(255, 152, 0);  // Orange
    return PdfColor(244, 67, 54);                   // Red
  }
}

final pdfReportService = PdfReportService();
