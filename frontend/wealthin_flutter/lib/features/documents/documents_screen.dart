import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/services/backend_config.dart';
import '../../core/theme/wealthin_theme.dart';

/// Document Generator Screen - Create professional financial documents
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: const DocumentsScreenBody(),
    );
  }
}

/// Body content for embedding in tabs
class DocumentsScreenBody extends StatefulWidget {
  const DocumentsScreenBody({super.key});

  @override
  State<DocumentsScreenBody> createState() => _DocumentsScreenBodyState();
}

class _DocumentsScreenBodyState extends State<DocumentsScreenBody> {
  final List<DocumentTemplate> _templates = [
    DocumentTemplate(
      type: 'loan_application',
      name: 'Loan Application',
      description: 'Apply for personal, home, or vehicle loans',
      icon: Icons.account_balance,
      color: WealthInTheme.navy,
    ),
    DocumentTemplate(
      type: 'invoice',
      name: 'Invoice',
      description: 'Generate professional invoices for goods or services',
      icon: Icons.receipt_long,
      color: WealthInTheme.emerald,
    ),
    DocumentTemplate(
      type: 'receipt',
      name: 'Payment Receipt',
      description: 'Issue receipts for payments received',
      icon: Icons.receipt,
      color: WealthInTheme.gold,
    ),
    DocumentTemplate(
      type: 'project_report',
      name: 'Project Report',
      description: 'Create detailed project or business reports',
      icon: Icons.description,
      color: WealthInTheme.purple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Document',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate professional financial documents with AI assistance',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: _templates.length,
            itemBuilder: (context, index) {
              final template = _templates[index];
              return _DocumentTemplateCard(
                template: template,
                onTap: () => _showDocumentForm(template),
              ).animate(delay: (100 * index).ms).fadeIn().scale();
            },
          ),
        ],
      ),
    );
  }

  void _showDocumentForm(DocumentTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentFormScreen(template: template),
      ),
    );
  }
}

/// Template data model
class DocumentTemplate {
  final String type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const DocumentTemplate({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Template card widget
class _DocumentTemplateCard extends StatelessWidget {
  final DocumentTemplate template;
  final VoidCallback onTap;

  const _DocumentTemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: template.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  template.icon,
                  size: 32,
                  color: template.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                template.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                template.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Document form screen for filling out template details
class DocumentFormScreen extends StatefulWidget {
  final DocumentTemplate template;

  const DocumentFormScreen({super.key, required this.template});

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  bool _isGenerating = false;

  // Dynamic form controllers based on template type
  late List<FormFieldConfig> _fields;

  @override
  void initState() {
    super.initState();
    _fields = _getFieldsForTemplate(widget.template.type);
  }

  List<FormFieldConfig> _getFieldsForTemplate(String type) {
    switch (type) {
      case 'loan_application':
        return [
          FormFieldConfig(
            key: 'applicant_name',
            label: 'Full Name',
            required: true,
          ),
          FormFieldConfig(key: 'dob', label: 'Date of Birth'),
          FormFieldConfig(key: 'address', label: 'Address', multiline: true),
          FormFieldConfig(
            key: 'phone',
            label: 'Phone Number',
            keyboardType: TextInputType.phone,
          ),
          FormFieldConfig(
            key: 'email',
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          FormFieldConfig(key: 'pan', label: 'PAN Number'),
          FormFieldConfig(
            key: 'loan_type',
            label: 'Loan Type',
            hint: 'Personal, Home, Vehicle, etc.',
          ),
          FormFieldConfig(
            key: 'loan_amount',
            label: 'Loan Amount (₹)',
            required: true,
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(
            key: 'tenure_months',
            label: 'Tenure (Months)',
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(
            key: 'purpose',
            label: 'Purpose of Loan',
            multiline: true,
          ),
          FormFieldConfig(
            key: 'employment_type',
            label: 'Employment Type',
            hint: 'Salaried/Self-employed',
          ),
          FormFieldConfig(key: 'employer', label: 'Employer/Business Name'),
          FormFieldConfig(
            key: 'monthly_income',
            label: 'Monthly Income (₹)',
            keyboardType: TextInputType.number,
          ),
        ];
      case 'invoice':
        return [
          FormFieldConfig(
            key: 'from_name',
            label: 'Your Name/Company',
            required: true,
          ),
          FormFieldConfig(
            key: 'from_address',
            label: 'Your Address',
            multiline: true,
          ),
          FormFieldConfig(
            key: 'to_name',
            label: 'Bill To (Name)',
            required: true,
          ),
          FormFieldConfig(
            key: 'to_address',
            label: 'Bill To (Address)',
            multiline: true,
          ),
          FormFieldConfig(key: 'invoice_number', label: 'Invoice Number'),
          FormFieldConfig(
            key: 'item_description',
            label: 'Item/Service Description',
            required: true,
            multiline: true,
          ),
          FormFieldConfig(
            key: 'quantity',
            label: 'Quantity',
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(
            key: 'rate',
            label: 'Rate (₹)',
            required: true,
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(
            key: 'tax_rate',
            label: 'Tax Rate (%)',
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(key: 'notes', label: 'Notes', multiline: true),
        ];
      case 'receipt':
        return [
          FormFieldConfig(
            key: 'received_from',
            label: 'Received From',
            required: true,
          ),
          FormFieldConfig(
            key: 'amount',
            label: 'Amount (₹)',
            required: true,
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(
            key: 'payment_mode',
            label: 'Payment Mode',
            hint: 'Cash/UPI/Bank Transfer',
          ),
          FormFieldConfig(
            key: 'description',
            label: 'For (Description)',
            required: true,
            multiline: true,
          ),
          FormFieldConfig(key: 'receipt_number', label: 'Receipt Number'),
        ];
      case 'project_report':
        return [
          FormFieldConfig(key: 'title', label: 'Report Title', required: true),
          FormFieldConfig(key: 'prepared_by', label: 'Prepared By'),
          FormFieldConfig(
            key: 'executive_summary',
            label: 'Executive Summary',
            multiline: true,
            required: true,
          ),
          FormFieldConfig(
            key: 'objectives',
            label: 'Project Objectives',
            multiline: true,
          ),
          FormFieldConfig(
            key: 'methodology',
            label: 'Methodology/Approach',
            multiline: true,
          ),
          FormFieldConfig(
            key: 'total_investment',
            label: 'Total Investment (₹)',
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(
            key: 'expected_revenue',
            label: 'Expected Revenue (₹)',
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(
            key: 'projected_profit',
            label: 'Projected Profit (₹)',
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(
            key: 'breakeven_period',
            label: 'Break-even Period',
            hint: 'e.g., 18 months',
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Template header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.template.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.template.icon,
                      size: 40,
                      color: widget.template.color,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.template.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.template.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form fields
              ..._fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: field.label,
                      hintText: field.hint,
                      border: const OutlineInputBorder(),
                      filled: true,
                    ),
                    keyboardType: field.keyboardType,
                    maxLines: field.multiline ? 3 : 1,
                    validator: field.required
                        ? (value) => value?.isEmpty == true ? 'Required' : null
                        : null,
                    onSaved: (value) => _formData[field.key] = value,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Generate button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.template.color,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateDocument() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isGenerating = true);

    try {
      // Prepare content based on template type
      final content = _prepareContent();

      final response = await http.post(
        Uri.parse('${backendConfig.baseUrl}/documents/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doc_type': widget.template.type,
          'title': widget.template.name,
          'content': content,
          'user_info': {},
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          await _savePdf(json['pdf_base64'], json['filename']);
        } else {
          throw Exception('Generation failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating document: $e'),
            backgroundColor: WealthInTheme.coral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Map<String, dynamic> _prepareContent() {
    final content = Map<String, dynamic>.from(_formData);

    // Handle invoice items specially
    if (widget.template.type == 'invoice') {
      content['items'] = [
        {
          'description': _formData['item_description'] ?? '',
          'quantity': int.tryParse(_formData['quantity'] ?? '1') ?? 1,
          'rate': double.tryParse(_formData['rate'] ?? '0') ?? 0,
        },
      ];
      content['tax_rate'] = double.tryParse(_formData['tax_rate'] ?? '0') ?? 0;
    }

    // Handle project report sections
    if (widget.template.type == 'project_report') {
      content['sections'] = [];
      if (_formData['executive_summary']?.isNotEmpty == true) {
        content['sections'].add({
          'heading': 'Executive Summary',
          'content': _formData['executive_summary'],
        });
      }
      if (_formData['objectives']?.isNotEmpty == true) {
        content['sections'].add({
          'heading': 'Project Objectives',
          'content': _formData['objectives'],
        });
      }
      if (_formData['methodology']?.isNotEmpty == true) {
        content['sections'].add({
          'heading': 'Methodology',
          'content': _formData['methodology'],
        });
      }

      // Financial summary
      if (_formData['total_investment']?.isNotEmpty == true) {
        content['financial_summary'] = {
          'total_investment':
              double.tryParse(_formData['total_investment'] ?? '0') ?? 0,
          'expected_revenue':
              double.tryParse(_formData['expected_revenue'] ?? '0') ?? 0,
          'projected_profit':
              double.tryParse(_formData['projected_profit'] ?? '0') ?? 0,
          'breakeven_period': _formData['breakeven_period'] ?? 'N/A',
        };
      }
    }

    // Convert numeric fields
    for (final key in [
      'loan_amount',
      'monthly_income',
      'amount',
      'tenure_months',
    ]) {
      if (content[key] != null) {
        content[key] = double.tryParse(content[key].toString()) ?? 0;
      }
    }

    return content;
  }

  Future<void> _savePdf(String base64Data, String filename) async {
    try {
      final bytes = base64Decode(base64Data);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document saved to: ${file.path}'),
            backgroundColor: WealthInTheme.emerald,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: WealthInTheme.coral,
          ),
        );
      }
    }
  }
}

/// Configuration for a form field
class FormFieldConfig {
  final String key;
  final String label;
  final String? hint;
  final bool required;
  final bool multiline;
  final TextInputType? keyboardType;

  const FormFieldConfig({
    required this.key,
    required this.label,
    this.hint,
    this.required = false,
    this.multiline = false,
    this.keyboardType,
  });
}
