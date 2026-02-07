import 'dart:ui';
// TODO: Firebase migration - removed wealthin_client import
// import 'package:wealthin_client/wealthin_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/wealthin_theme.dart';
// TODO: Firebase migration - removed main.dart import (was used for Serverpod client)
// import '../../main.dart';

/// Mock BusinessIdea class for Firebase migration
class BusinessIdea {
  final String idea;
  final String title;
  final int score;
  final String estimatedInvestment;
  final String timeToBreakeven;
  final String marketAnalysis;
  final String targetAudience;
  final String revenueModel;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> suggestions;
  final List<String> nextSteps;
  final String summary;

  BusinessIdea({
    required this.idea,
    String? title,
    required this.score,
    required this.estimatedInvestment,
    required this.timeToBreakeven,
    required this.marketAnalysis,
    required this.targetAudience,
    required this.revenueModel,
    required this.strengths,
    required this.weaknesses,
    required this.suggestions,
    required this.nextSteps,
    required this.summary,
  }) : title = title ?? idea;
}

/// Brainstorm Screen - Business idea generator and analyzer
class BrainstormScreen extends StatelessWidget {
  const BrainstormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Brainstorm'),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: const BrainstormScreenBody(),
    );
  }
}

/// Brainstorm Screen Body - for embedding in tabs
class BrainstormScreenBody extends StatefulWidget {
  const BrainstormScreenBody({super.key});

  @override
  State<BrainstormScreenBody> createState() => _BrainstormScreenBodyState();
}

class _BrainstormScreenBodyState extends State<BrainstormScreenBody> {
  final TextEditingController _ideaController = TextEditingController();
  bool _isAnalyzing = false;
  BusinessIdea? _currentIdea;
  final List<BusinessIdea> _savedIdeas = [];

  @override
  void dispose() {
    _ideaController.dispose();
    super.dispose();
  }

  Future<void> _analyzeIdea() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) return;

    setState(() => _isAnalyzing = true);

    // TODO: Firebase migration - implement with Cloud Functions or Python sidecar
    try {
      // Mock analysis result
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _currentIdea = BusinessIdea(
            idea: idea,
            score: 75,
            estimatedInvestment: "₹5-10 Lakhs",
            timeToBreakeven: "12-18 months",
            marketAnalysis:
                'This idea shows good market potential in the current economic climate. '
                'The target demographic is growing and there\'s room for differentiation.',
            targetAudience:
                'Urban professionals aged 25-45, middle to upper-middle class, '
                'tech-savvy individuals who value convenience.',
            revenueModel:
                'Subscription-based model with tiered pricing. '
                'Additional revenue through premium features and partnerships.',
            strengths: [
              'Growing market demand',
              'Low initial capital requirement',
              'Scalable business model',
              'Clear value proposition',
            ],
            weaknesses: [
              'Competitive market landscape',
              'Customer acquisition costs',
              'Building trust with new users',
              'Operational complexity at scale',
            ],
            suggestions: [
              "Add premium features",
              "Consider B2B model",
              "Build community around product",
            ],
            nextSteps: [
              'Conduct detailed market research',
              'Create a minimum viable product (MVP)',
              'Identify potential early adopters',
              'Develop a go-to-market strategy',
            ],
            summary:
                'A promising idea with solid fundamentals. Focus on differentiation '
                'and building a strong initial user base.',
          );
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing idea: $e')),
        );
      }
    }
  }

  void _saveIdea() {
    if (_currentIdea != null) {
      setState(() {
        _savedIdeas.insert(0, _currentIdea!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Idea saved!')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_savedIdeas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Badge(
                label: Text('${_savedIdeas.length}'),
                child: IconButton(
                  icon: const Icon(Icons.bookmark),
                  onPressed: () => _showSavedIdeas(context),
                  tooltip: 'Saved ideas',
                ),
              ),
            ),
          ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
        Expanded(
          child: _buildContent(theme),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.primary.withValues(alpha: 0.05),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _GlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lightbulb,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Business Idea Analyzer',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Powered by AI & Market Research',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _ideaController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'Describe your business idea...\n\nExample: A subscription service for homemade healthy tiffins for office workers',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing ? null : _analyzeIdea,
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            _isAnalyzing ? 'Analyzing...' : 'Analyze Idea',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 600.ms).moveY(begin: 20, end: 0),

            const SizedBox(height: 24),

            // Analysis Results
            if (_currentIdea != null) ...[
              _IdeaAnalysisCard(
                idea: _currentIdea!,
                onSave: _saveIdea,
              ).animate().fadeIn(duration: 800.ms).moveY(begin: 30, end: 0),
            ] else ...[
              // Sample Ideas
              Text(
                'Popular Business Ideas',
                style: theme.textTheme.titleLarge,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 16),
              _SampleIdeaTile(
                title: 'Cloud Kitchen',
                description: 'Start a delivery-only restaurant',
                icon: Icons.restaurant,
                onTap: () {
                  _ideaController.text =
                      'A cloud kitchen specializing in healthy Indian meals with subscription options';
                },
              ).animate(delay: 300.ms).fadeIn().moveX(begin: -20, end: 0),
              _SampleIdeaTile(
                title: 'EdTech Platform',
                description: 'Online courses for skill development',
                icon: Icons.school,
                onTap: () {
                  _ideaController.text =
                      'An e-learning platform for vernacular language programming courses';
                },
              ).animate(delay: 400.ms).fadeIn().moveX(begin: -20, end: 0),
              _SampleIdeaTile(
                title: 'Sustainable Products',
                description: 'Eco-friendly everyday items',
                icon: Icons.eco,
                onTap: () {
                  _ideaController.text =
                      'An e-commerce store for sustainable and eco-friendly home products';
                },
              ).animate(delay: 500.ms).fadeIn().moveX(begin: -20, end: 0),
            ],
          ],
        ),
      ),
    );
  }

  void _showSavedIdeas(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: WealthInTheme.gray300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Saved Ideas (${_savedIdeas.length})',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _savedIdeas.length,
                        itemBuilder: (context, index) {
                          final idea = _savedIdeas[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: _ScoreCircle(score: idea.score),
                              title: Text(
                                idea.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(idea.estimatedInvestment),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() => _savedIdeas.removeAt(index));
                                  Navigator.pop(context);
                                  if (_savedIdeas.isNotEmpty) {
                                    _showSavedIdeas(context);
                                  }
                                },
                              ),
                            ),
                          ).animate().fadeIn(delay: (index * 100).ms).moveX();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double opacity;

  const _GlassContainer({
    required this.child,
    this.opacity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: AppTheme.glassDecoration(opacity: opacity),
          child: child,
        ),
      ),
    );
  }
}

class _IdeaAnalysisCard extends StatelessWidget {
  final BusinessIdea idea;
  final VoidCallback onSave;

  const _IdeaAnalysisCard({required this.idea, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ScoreCircle(score: idea.score, size: 70),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viability Score',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      Text(
                        _getScoreLabel(idea.score),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: _getScoreColor(idea.score),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add),
                  tooltip: 'Save idea',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(height: 40),

            // Investment & Timeline
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.currency_rupee,
                    label: 'Investment',
                    value: idea.estimatedInvestment,
                  ),
                ),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.timer,
                    label: 'Breakeven',
                    value: idea.timeToBreakeven,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Strengths
            _AnalysisSection(
              title: 'Strengths',
              icon: Icons.check_circle,
              color: AppTheme.success,
              items: idea.strengths,
            ),
            const SizedBox(height: 20),

            // Weaknesses
            _AnalysisSection(
              title: 'Challenges',
              icon: Icons.warning,
              color: WealthInTheme.warning,
              items: idea.weaknesses,
            ),
            const SizedBox(height: 20),

            // Suggestions
            _AnalysisSection(
              title: 'Recommendations',
              icon: Icons.lightbulb,
              color: WealthInTheme.purple,
              items: idea.suggestions,
            ),
          ],
        ),
      ),
    );
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Moderate';
    return 'Needs Work';
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return const Color(0xFF7CB342);
    if (score >= 40) return WealthInTheme.warning;
    return AppTheme.error;
  }
}

class _ScoreCircle extends StatelessWidget {
  final int score;
  final double size;

  const _ScoreCircle({required this.score, this.size = 48});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score >= 80) {
      color = AppTheme.success;
    } else if (score >= 60) {
      color = const Color(0xFF7CB342);
    } else if (score >= 40) {
      color = WealthInTheme.warning;
    } else {
      color = AppTheme.error;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 6,
              color: color.withValues(alpha: 0.15),
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$score',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: size * 0.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalysisSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _AnalysisSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SampleIdeaTile extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _SampleIdeaTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      opacity: 0.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}
