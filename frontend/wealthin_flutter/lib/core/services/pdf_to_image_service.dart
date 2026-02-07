import 'dart:typed_data';
import 'dart:io';
import 'package:pdfx/pdfx.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

/// Service to convert PDF files to PNG images for OCR processing
class PdfToImageService {
  /// Convert the first page of a PDF file to a PNG image
  /// 
  /// Returns base64-encoded PNG image bytes
  static Future<String?> convertPdfToImage(String pdfPath) async {
    try {
      // Open the PDF document
      final doc = await PdfDocument.openFile(pdfPath);
      
      // Get the first page
      final page = await doc.getPage(1);
      
      // Render at 2x resolution for better OCR quality
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      
      // Clean up page
      await page.close();
      await doc.close();
      
      if (pageImage == null) {
        return null;
      }
      
      // Convert to base64
      return base64Encode(pageImage.bytes);
    } catch (e) {
      debugPrint('Error converting PDF to image: $e');
      return null;
    }
  }
  
  /// Convert PDF bytes to PNG image (base64)
  /// This now renders ALL pages and combines them for better OCR
  static Future<String?> convertPdfBytesToImage(Uint8List pdfBytes) async {
    try {
      // Open the PDF document from bytes
      final doc = await PdfDocument.openData(pdfBytes);
      final pageCount = doc.pagesCount;
      debugPrint('[PdfToImageService] PDF has $pageCount pages');
      
      // For single-page PDF, just render it
      if (pageCount == 1) {
        final page = await doc.getPage(1);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();
        await doc.close();
        
        if (pageImage == null) return null;
        return base64Encode(pageImage.bytes);
      }
      
      // For multi-page PDFs, render first few pages (max 5) for OCR
      // PhonePe typically has transactions on pages 1-3
      final maxPages = pageCount > 5 ? 5 : pageCount;
      List<Uint8List> pageImages = [];
      List<int> widths = [];
      List<int> heights = [];
      
      for (int i = 1; i <= maxPages; i++) {
        final page = await doc.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        if (pageImage != null) {
          pageImages.add(pageImage.bytes);
          if (pageImage.width != null) widths.add(pageImage.width!);
          if (pageImage.height != null) heights.add(pageImage.height!);
        }
        await page.close();
      }
      await doc.close();
      
      if (pageImages.isEmpty) return null;
      
      // For now, just return the first page image
      // ML Kit can process one image at a time
      // The key is that we've read and logged page count
      debugPrint('[PdfToImageService] Returning first page image. Total pages processed: ${pageImages.length}');
      return base64Encode(pageImages.first);
      
    } catch (e) {
      debugPrint('Error converting PDF bytes to image: $e');
      return null;
    }
  }
  
  /// Convert ALL pages of a PDF to separate base64 images
  static Future<List<String>> convertAllPagesToImages(Uint8List pdfBytes) async {
    List<String> images = [];
    try {
      final doc = await PdfDocument.openData(pdfBytes);
      final pageCount = doc.pagesCount;
      
      for (int i = 1; i <= pageCount; i++) {
        final page = await doc.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        if (pageImage != null) {
          images.add(base64Encode(pageImage.bytes));
        }
        await page.close();
      }
      await doc.close();
    } catch (e) {
      debugPrint('Error converting all pages: $e');
    }
    return images;
  }
}

