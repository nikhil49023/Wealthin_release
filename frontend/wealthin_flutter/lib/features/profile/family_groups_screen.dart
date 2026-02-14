import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wealthin_flutter/core/theme/app_theme.dart';
import 'package:wealthin_flutter/core/services/database_helper.dart';
import 'package:wealthin_flutter/core/services/data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Family Groups Screen - Manage shared account groups
class FamilyGroupsScreen extends StatefulWidget {
  const FamilyGroupsScreen({super.key});

  @override
  State<FamilyGroupsScreen> createState() => _FamilyGroupsScreenState();
}

class _FamilyGroupsScreenState extends State<FamilyGroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<String> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? 'default_user';
  }

  Future<void> _loadGroups() async {
    try {
      final userId = await _getCurrentUserId();
      final groups = await DataService().getFamilyGroups(userId);

      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading groups: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.group_add, color: AppTheme.emerald),
            SizedBox(width: 12),
            Text('Create Family Group'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g., Family Budget',
                  prefixIcon: Icon(Icons.label),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'What is this group for?',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a group name'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final userId = await _getCurrentUserId();

        final group = await DataService().createFamilyGroup(
          userId: userId,
          name: nameController.text.trim(),
          description: descriptionController.text.trim(),
        );

        if (group != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Created group "${nameController.text.trim()}"'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );

          await _loadGroups(); // Refresh list
        } else if (mounted) {
          throw Exception('Failed to create group');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating group: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _viewGroupDetails(Map<String, dynamic> group) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GroupDetailsScreen(group: group),
      ),
    ).then((_) => _loadGroups()); // Refresh after returning
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "${group['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final db = await DatabaseHelper().database;
        
        // Delete group members first
        await db.delete('group_members', where: 'group_id = ?', whereArgs: [group['id']]);
        
        // Delete group
        await db.delete('groups', where: 'id = ?', whereArgs: [group['id']]);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Group deleted'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          
          await _loadGroups(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting group: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Groups'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return _GroupCard(
                      group: group,
                      onTap: () => _viewGroupDetails(group),
                      onDelete: () => _deleteGroup(group),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people,
                size: 64,
                color: AppTheme.emerald,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Family Groups Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to share financial analysis with family members',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Group'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GroupCard({
    required this.group,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberCount = group['member_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people,
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
                      group['name'],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: AppTheme.expenseRed,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const _GroupDetailsScreen({required this.group});

  @override
  State<_GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<_GroupDetailsScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final groupId = widget.group['id'] as int;
      final members = await DataService().getGroupMembers(groupId);

      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMember() async {
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'member@example.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: AppTheme.navy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'An invitation will be sent to this email',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final groupId = widget.group['id'] as int;
        final email = emailController.text.trim();

        final success = await DataService().addGroupMember(
          groupId: groupId,
          email: email,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invitation sent to $email'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadMembers(); // Refresh member list
        } else if (mounted) {
          throw Exception('Failed to add member');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _generateInviteLink() async {
    try {
      final groupId = widget.group['id'] as int;
      final inviteLink = await DataService().generateInviteLink(groupId);

      if (inviteLink != null) {
        await Clipboard.setData(ClipboardData(text: inviteLink));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Invite link copied to clipboard'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        throw Exception('Failed to generate invite link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group['name']),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.7)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.people,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.group['name'],
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (widget.group['description'] != null &&
                                        widget.group['description'].toString().isNotEmpty)
                                      Text(
                                        widget.group['description'],
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Members Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Members (${_members.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addMember,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_members.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No members yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._members.map((member) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.emerald,
                              child: Text(
                                member['user_id'].toString()[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(member['user_id']),
                            subtitle: Text(member['role'] ?? 'member'),
                            trailing: member['role'] == 'admin'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.gold.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.navy,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        )),

                  const SizedBox(height: 24),

                  // Invite Options
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.link, color: AppTheme.secondary),
                          title: const Text('Generate Invite Link'),
                          subtitle: const Text('Share a link to invite members'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _generateInviteLink,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
