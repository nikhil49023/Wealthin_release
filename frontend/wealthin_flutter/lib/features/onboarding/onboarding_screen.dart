import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/wealthin_theme.dart';

/// Onboarding Screen - Collects user profile information
/// First-time setup with personal, family, occupation, and business details
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _occupationController = TextEditingController();
  final _annualIncomeController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _businessContactController = TextEditingController();
  final _businessLocationController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  
  // Family members
  int _adults = 1;
  int _children = 0;
  
  // Business toggle
  bool _hasBusiness = false;
  bool _shareBusinessInfo = true;
  
  // Occupation options
  final List<String> _occupationOptions = [
    'Salaried Employee',
    'Self-Employed',
    'Business Owner',
    'Freelancer',
    'Student',
    'Retired',
    'Homemaker',
    'Other',
  ];
  
  String? _selectedOccupation;
  
  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _occupationController.dispose();
    _annualIncomeController.dispose();
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _businessContactController.dispose();
    _businessLocationController.dispose();
    _businessDescriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save personal info
    await prefs.setString('user_first_name', _firstNameController.text.trim());
    await prefs.setString('user_last_name', _lastNameController.text.trim());
    await prefs.setString('user_occupation', _selectedOccupation ?? '');
    await prefs.setString('user_annual_income', _annualIncomeController.text.trim());
    await prefs.setInt('family_adults', _adults);
    await prefs.setInt('family_children', _children);
    
    // Save business info
    await prefs.setBool('has_business', _hasBusiness);
    if (_hasBusiness) {
      await prefs.setString('business_name', _businessNameController.text.trim());
      await prefs.setString('business_type', _businessTypeController.text.trim());
      await prefs.setString('business_contact', _businessContactController.text.trim());
      await prefs.setString('business_location', _businessLocationController.text.trim());
      await prefs.setString('business_description', _businessDescriptionController.text.trim());
      await prefs.setBool('share_business_info', _shareBusinessInfo);
    }
    
    // Mark onboarding complete
    await prefs.setBool('onboarding_complete', true);
  }
  
  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> _completeOnboarding() async {
    await _saveProfile();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(theme),
                  _buildPersonalInfoPage(theme),
                  _buildFamilyOccupationPage(theme),
                  _buildBusinessPage(theme),
                ],
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: _currentPage == 3 ? _completeOnboarding : _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_currentPage == 3 ? 'Get Started' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWelcomePage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo/Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 60,
              color: Colors.white,
            ),
          ).animate().scale(delay: 200.ms).fadeIn(),
          const SizedBox(height: 40),
          Text(
            'Welcome to WealthIn',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          Text(
            'Your personal AI-powered financial advisor.\nLet\'s set up your profile for personalized insights.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
          const SizedBox(height: 48),
          
          // Feature highlights
          _buildFeatureCard(
            theme,
            Icons.insights_rounded,
            'Smart Analysis',
            'AI-powered spending insights tailored to you',
          ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),
          const SizedBox(height: 12),
          _buildFeatureCard(
            theme,
            Icons.family_restroom_rounded,
            'Family Budgeting',
            'Track expenses for your entire household',
          ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),
          const SizedBox(height: 12),
          _buildFeatureCard(
            theme,
            Icons.business_rounded,
            'Business Growth',
            'Promote your business to other WealthIn users',
          ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1),
        ],
      ),
    );
  }
  
  Widget _buildFeatureCard(ThemeData theme, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPersonalInfoPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us about yourself',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'This helps us personalize your financial advice',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),
          
          // First Name
          _buildTextField(
            controller: _firstNameController,
            label: 'First Name',
            icon: Icons.person_outline_rounded,
            hint: 'Enter your first name',
          ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
          const SizedBox(height: 20),
          
          // Last Name
          _buildTextField(
            controller: _lastNameController,
            label: 'Last Name',
            icon: Icons.badge_outlined,
            hint: 'Enter your last name',
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
          const SizedBox(height: 20),
          
          // Annual Income
          _buildTextField(
            controller: _annualIncomeController,
            label: 'Annual Income (₹)',
            icon: Icons.currency_rupee_rounded,
            hint: 'e.g., 600000',
            keyboardType: TextInputType.number,
          ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
          const SizedBox(height: 16),
          
          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your data is stored securely on your device and never shared.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
  
  Widget _buildFamilyOccupationPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Family & Occupation',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'Help us understand your household expenses better',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),
          
          // Occupation Dropdown
          Text(
            'Occupation',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedOccupation,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.work_outline_rounded),
              hintText: 'Select your occupation',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: _occupationOptions.map((occ) {
              return DropdownMenuItem(value: occ, child: Text(occ));
            }).toList(),
            onChanged: (val) => setState(() => _selectedOccupation = val),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
          const SizedBox(height: 32),
          
          // Family Members
          Text(
            'Family Members',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Adults counter
          _buildCounterRow(
            theme,
            'Adults (18+ years)',
            Icons.person_rounded,
            _adults,
            (val) => setState(() => _adults = val),
            min: 1,
            max: 10,
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
          const SizedBox(height: 16),
          
          // Children counter
          _buildCounterRow(
            theme,
            'Children (under 18)',
            Icons.child_care_rounded,
            _children,
            (val) => setState(() => _children = val),
            min: 0,
            max: 10,
          ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
          const SizedBox(height: 24),
          
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.family_restroom_rounded,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family of ${_adults + _children}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$_adults adult${_adults > 1 ? 's' : ''}, $_children child${_children != 1 ? 'ren' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.95, 0.95)),
        ],
      ),
    );
  }
  
  Widget _buildBusinessPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Details',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 8),
          Text(
            'Optional: Promote your business to other users',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 24),
          
          // Business toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Do you own a business?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Get discovered by other users',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hasBusiness,
                  onChanged: (val) => setState(() => _hasBusiness = val),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
          
          if (_hasBusiness) ...[
            const SizedBox(height: 24),
            
            // Business Name
            _buildTextField(
              controller: _businessNameController,
              label: 'Business Name',
              icon: Icons.business_rounded,
              hint: 'Enter your business name',
            ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),
            const SizedBox(height: 16),
            
            // Business Type
            _buildTextField(
              controller: _businessTypeController,
              label: 'Business Type',
              icon: Icons.category_rounded,
              hint: 'e.g., Retail, Restaurant, Services',
            ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.1),
            const SizedBox(height: 16),
            
            // Contact
            _buildTextField(
              controller: _businessContactController,
              label: 'Business Contact',
              icon: Icons.phone_rounded,
              hint: 'Phone number or email',
              keyboardType: TextInputType.phone,
            ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
            const SizedBox(height: 16),
            
            // Location
            _buildTextField(
              controller: _businessLocationController,
              label: 'Location',
              icon: Icons.location_on_rounded,
              hint: 'City, Area',
            ).animate().fadeIn(delay: 450.ms).slideX(begin: 0.1),
            const SizedBox(height: 16),
            
            // Description
            _buildTextField(
              controller: _businessDescriptionController,
              label: 'Brief Description',
              icon: Icons.description_rounded,
              hint: 'What does your business offer?',
              maxLines: 3,
            ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),
            const SizedBox(height: 20),
            
            // Share info toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WealthInTheme.regalGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WealthInTheme.regalGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        color: WealthInTheme.regalGold,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Promote to Other Users',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: WealthInTheme.vintageGold,
                          ),
                        ),
                      ),
                      Switch(
                        value: _shareBusinessInfo,
                        onChanged: (val) => setState(() => _shareBusinessInfo = val),
                        activeThumbColor: WealthInTheme.regalGold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📢 When enabled, your business details (name, type, contact, location) will be shared with other WealthIn users through the AI Chat Advisor. This can help grow your business by connecting you with potential customers!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WealthInTheme.vintageGold,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 550.ms).scale(begin: const Offset(0.95, 0.95)),
          ],
          
          if (!_hasBusiness) ...[
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.skip_next_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No business? No problem!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    'You can add business details anytime from settings',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCounterRow(
    ThemeData theme,
    String label,
    IconData icon,
    int value,
    Function(int) onChanged, {
    int min = 0,
    int max = 10,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          // Decrease button
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: theme.colorScheme.primary,
          ),
          // Value
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Increase button
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// Helper to check if onboarding is complete
Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
}

/// Get user profile data
Future<Map<String, dynamic>> getUserProfile() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'firstName': prefs.getString('user_first_name') ?? '',
    'lastName': prefs.getString('user_last_name') ?? '',
    'occupation': prefs.getString('user_occupation') ?? '',
    'annualIncome': prefs.getString('user_annual_income') ?? '',
    'familyAdults': prefs.getInt('family_adults') ?? 1,
    'familyChildren': prefs.getInt('family_children') ?? 0,
    'hasBusiness': prefs.getBool('has_business') ?? false,
    'businessName': prefs.getString('business_name') ?? '',
    'businessType': prefs.getString('business_type') ?? '',
    'businessContact': prefs.getString('business_contact') ?? '',
    'businessLocation': prefs.getString('business_location') ?? '',
    'businessDescription': prefs.getString('business_description') ?? '',
    'shareBusinessInfo': prefs.getBool('share_business_info') ?? false,
  };
}
