import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wealthin_flutter/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Government Services Screen - Access MSME schemes, verification, and directory
class GovernmentServicesScreen extends StatefulWidget {
  const GovernmentServicesScreen({super.key});

  @override
  State<GovernmentServicesScreen> createState() =>
      _GovernmentServicesScreenState();
}

class _GovernmentServicesScreenState extends State<GovernmentServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Government Services'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance), text: 'Schemes'),
            Tab(icon: Icon(Icons.verified_user), text: 'Verify'),
            Tab(icon: Icon(Icons.business), text: 'MSME Directory'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SchemesTab(),
          _VerifyTab(),
          _MSMEDirectoryTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: Government Schemes
// ============================================================================

class _SchemesTab extends StatelessWidget {
  const _SchemesTab();

  @override
  Widget build(BuildContext context) {
    final schemes = [
      {
        'name': 'MUDRA (Pradhan Mantri MUDRA Yojana)',
        'icon': Icons.account_balance_wallet,
        'color': Colors.blue,
        'loan_amount': 'Up to ₹10 lakhs',
        'description':
            'Micro-units development loan for non-corporate small business sector',
        'categories': [
          'Shishu: Up to ₹50,000',
          'Kishore: ₹50,001 to ₹5 lakhs',
          'Tarun: ₹5,00,001 to ₹10 lakhs'
        ],
        'eligibility': [
          'Indian citizen',
          'Business in manufacturing, trading, or service sector',
          'Income-generating activity'
        ],
        'interest_rate': '8-12% per annum (varies by bank)',
        'collateral': 'No collateral required',
        'website': 'https://www.mudra.org.in'
      },
      {
        'name': 'PMEGP',
        'icon': Icons.work,
        'color': Colors.green,
        'loan_amount': 'Manufacturing: ₹10-25L, Services: ₹5-10L',
        'description':
            'Prime Minister Employment Generation Programme - Credit-linked subsidy',
        'subsidy': [
          'General category: 15-25% subsidy',
          'SC/ST/OBC/Women/Minorities: 25-35% subsidy'
        ],
        'eligibility': [
          'Age 18 years and above',
          'At least 8th pass for projects above ₹10 lakhs',
          'New enterprise only (not existing business)'
        ],
        'margin_money': '5-10% of project cost',
        'website': 'https://www.kviconline.gov.in/pmegp'
      },
      {
        'name': 'Stand-Up India',
        'icon': Icons.people,
        'color': Colors.orange,
        'loan_amount': '₹10 lakh to ₹1 crore',
        'description': 'Bank loans for SC/ST and women entrepreneurs',
        'eligibility': [
          'SC/ST and/or Women entrepreneur',
          'Age 18 years and above',
          'Loan for greenfield enterprise (manufacturing, services, trading)'
        ],
        'interest_rate': 'Base rate + 3% + tenor premium',
        'repayment': 'Up to 7 years with moratorium',
        'website': 'https://www.standupmitra.in'
      },
      {
        'name': 'Startup India Seed Fund Scheme',
        'icon': Icons.rocket_launch,
        'color': Colors.purple,
        'grant': 'Up to ₹20 lakhs as grant',
        'debt': 'Up to ₹50 lakhs as debt',
        'description':
            'Financial assistance to startups for proof of concept, prototype development',
        'eligibility': [
          'DPIIT recognized startup',
          'Incorporated not more than 2 years ago',
          'Working towards innovation/development'
        ],
        'website': 'https://www.startupindia.gov.in'
      },
      {
        'name': 'CGTMSE',
        'icon': Icons.shield,
        'color': Colors.teal,
        'guarantee_cover': 'Up to ₹5 crore (75-85% guarantee)',
        'description':
            'Credit Guarantee Fund Trust for Micro and Small Enterprises - Collateral-free credit',
        'eligibility': [
          'New or existing MSME',
          'Loan from eligible lending institution'
        ],
        'fee': '0.75-1% annual service fee',
        'website': 'https://www.cgtmse.in'
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schemes.length,
      itemBuilder: (context, index) {
        final scheme = schemes[index];
        return _SchemeCard(scheme: scheme);
      },
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final Map<String, dynamic> scheme;

  const _SchemeCard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: (scheme['color'] as Color).withOpacity(0.2),
          child: Icon(
            scheme['icon'] as IconData,
            color: scheme['color'] as Color,
          ),
        ),
        title: Text(
          scheme['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(scheme['description'] as String),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Loan amount
                if (scheme.containsKey('loan_amount')) ...[
                  _buildDetailRow(
                    icon: Icons.attach_money,
                    label: 'Loan Amount',
                    value: scheme['loan_amount'] as String,
                  ),
                ],

                // Grant
                if (scheme.containsKey('grant')) ...[
                  _buildDetailRow(
                    icon: Icons.money,
                    label: 'Grant',
                    value: scheme['grant'] as String,
                  ),
                ],

                // Categories
                if (scheme.containsKey('categories')) ...[
                  const SizedBox(height: 12),
                  _buildSection(
                    'Categories',
                    scheme['categories'] as List<dynamic>,
                  ),
                ],

                // Subsidy
                if (scheme.containsKey('subsidy')) ...[
                  const SizedBox(height: 12),
                  _buildSection(
                    'Subsidy',
                    scheme['subsidy'] as List<dynamic>,
                  ),
                ],

                // Eligibility
                if (scheme.containsKey('eligibility')) ...[
                  const SizedBox(height: 12),
                  _buildSection(
                    'Eligibility',
                    scheme['eligibility'] as List<dynamic>,
                  ),
                ],

                // Interest rate
                if (scheme.containsKey('interest_rate')) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.percent,
                    label: 'Interest Rate',
                    value: scheme['interest_rate'] as String,
                  ),
                ],

                // Collateral
                if (scheme.containsKey('collateral')) ...[
                  _buildDetailRow(
                    icon: Icons.home,
                    label: 'Collateral',
                    value: scheme['collateral'] as String,
                  ),
                ],

                // Website
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _launchURL(scheme['website'] as String),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Visit Official Website'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(item as String)),
                ],
              ),
            )),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ============================================================================
// TAB 2: Verification
// ============================================================================

class _VerifyTab extends StatefulWidget {
  const _VerifyTab();

  @override
  State<_VerifyTab> createState() => _VerifyTabState();
}

class _VerifyTabState extends State<_VerifyTab> {
  final _panController = TextEditingController();
  final _gstinController = TextEditingController();
  final _udyamController = TextEditingController();

  @override
  void dispose() {
    _panController.dispose();
    _gstinController.dispose();
    _udyamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Card(
            color: AppTheme.gold.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.navy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verify PAN, GSTIN, and UDYAM registration numbers',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // PAN Verification
          _buildVerificationCard(
            title: 'Verify PAN',
            icon: Icons.credit_card,
            color: Colors.blue,
            controller: _panController,
            hint: 'ABCDE1234F',
            label: 'PAN Number',
            info: 'Format: 5 letters + 4 digits + 1 letter',
            onVerify: () => _showComingSoon(context, 'PAN Verification'),
          ),
          const SizedBox(height: 16),

          // GSTIN Verification
          _buildVerificationCard(
            title: 'Verify GSTIN',
            icon: Icons.receipt_long,
            color: Colors.green,
            controller: _gstinController,
            hint: '29ABCDE1234F1Z5',
            label: 'GSTIN Number',
            info: 'Format: 2 digits + 10 char PAN + 1 letter + 1 digit + 1 letter',
            onVerify: () => _showComingSoon(context, 'GSTIN Verification'),
          ),
          const SizedBox(height: 16),

          // UDYAM Verification
          _buildVerificationCard(
            title: 'Verify UDYAM Registration',
            icon: Icons.business_center,
            color: Colors.orange,
            controller: _udyamController,
            hint: 'UDYAM-XX-00-0000000',
            label: 'UDYAM Number',
            info: 'MSME/UDYAM registration number',
            onVerify: () => _showComingSoon(context, 'UDYAM Verification'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String hint,
    required String label,
    required String info,
    required VoidCallback onVerify,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(icon),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            Text(
              info,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onVerify,
                icon: const Icon(Icons.verified),
                label: const Text('Verify'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon'),
        backgroundColor: AppTheme.navy,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 3: MSME Directory
// ============================================================================

class _MSMEDirectoryTab extends StatefulWidget {
  const _MSMEDirectoryTab();

  @override
  State<_MSMEDirectoryTab> createState() => _MSMEDirectoryTabState();
}

class _MSMEDirectoryTabState extends State<_MSMEDirectoryTab> {
  final _searchController = TextEditingController();
  String? _selectedState;
  String? _selectedSector;

  final List<String> _states = [
    'Andhra Pradesh',
    'Karnataka',
    'Kerala',
    'Maharashtra',
    'Tamil Nadu',
    'Telangana',
    // Add more states
  ];

  final List<String> _sectors = [
    'Manufacturing',
    'Services',
    'Trading',
    'Food Processing',
    'Textiles',
    'IT/Software',
    // Add more sectors
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filters
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search MSMEs by name...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedState,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _states.map((state) {
                        return DropdownMenuItem(
                          value: state,
                          child: Text(state),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedState = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSector,
                      decoration: const InputDecoration(
                        labelText: 'Sector',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _sectors.map((sector) {
                        return DropdownMenuItem(
                          value: sector,
                          child: Text(sector),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedSector = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showComingSoon(context),
                  icon: const Icon(Icons.search),
                  label: const Text('Search Directory'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Info message
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'MSME Directory Search',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search for registered MSMEs by location and sector.\n\nRequires Government API integration.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _launchURL('https://udyamregistration.gov.in'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Visit UDYAM Portal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navy,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('MSME Directory Search - Coming Soon'),
        backgroundColor: AppTheme.navy,
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
