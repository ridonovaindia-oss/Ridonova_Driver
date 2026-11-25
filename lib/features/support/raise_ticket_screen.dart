import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_flushbar.dart';
import 'support_provider.dart';
import 'support_model.dart';

class RaiseTicketScreen extends ConsumerStatefulWidget {
  const RaiseTicketScreen({super.key});

  @override
  ConsumerState<RaiseTicketScreen> createState() => _RaiseTicketScreenState();
}

class _RaiseTicketScreenState extends ConsumerState<RaiseTicketScreen> {
  SupportCategory? _selectedCategory;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rideIdController = TextEditingController();
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;
  final String _submissionIdempotencyKey = const Uuid().v4();

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportProvider);
    final categories = supportState.categories;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Raise Support Ticket'), backgroundColor: AppColors.secondary, centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Issue Category',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              // Categories Dropdown / List
              DropdownButtonFormField<SupportCategory>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Select issue category',
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem<SupportCategory>(
                    value: cat,
                    child: Text(cat.name, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val;
                    if (val != null) {
                      _selectedPriority = val.priority;
                    }
                  });
                },
              ),

              const SizedBox(height: 16),

              // Subject Input
              const Text(
                'Subject',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'e.g. Toll charges missing in Ride #991204',
                ),
              ),

              const SizedBox(height: 16),

              // Ride ID Input (Conditional if required)
              if (_selectedCategory?.requiresRideId == true) ...[
                const Text(
                  'Ride ID (Required for this category)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _rideIdController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'e.g. RIDE-991204',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Description Input
              const Text(
                'Detailed Description',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Describe your issue in detail so support can assist quickly...',
                ),
              ),

              const SizedBox(height: 16),

              // Priority Selector
              const Text(
                'Priority Level',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPriority = val;
                    });
                  }
                },
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_isSubmitting || supportState.isActionLoading)
                      ? null
                      : () async {
                          if (_isSubmitting) return;
                          if (_selectedCategory == null) {
                            AppFlushbar.error(context, title: 'Category Required', message: 'Please select an issue category.');
                            return;
                          }
                          if (_subjectController.text.trim().isEmpty) {
                            AppFlushbar.error(context, title: 'Subject Required', message: 'Please enter a ticket subject.');
                            return;
                          }
                          if (_descriptionController.text.trim().isEmpty) {
                            AppFlushbar.error(context, title: 'Description Required', message: 'Please provide issue description.');
                            return;
                          }
                          if (_selectedCategory!.requiresRideId && _rideIdController.text.trim().isEmpty) {
                            AppFlushbar.error(context, title: 'Ride ID Required', message: 'This category requires a Ride ID.');
                            return;
                          }

                          setState(() => _isSubmitting = true);
                          final success = await ref
                              .read(supportProvider.notifier)
                              .createTicket(
                                category: _selectedCategory!.id,
                                subject: _subjectController.text.trim(),
                                description: _descriptionController.text.trim(),
                                rideId: _rideIdController.text.trim().isNotEmpty ? _rideIdController.text.trim() : null,
                                priority: _selectedPriority,
                                idempotencyKey: _submissionIdempotencyKey,
                              );

                          if (!context.mounted) return;
                          if (success) {
                            AppFlushbar.success(context, title: 'Ticket Raised', message: 'Your support ticket has been successfully created.');
                            Navigator.pop(context);
                          } else {
                            setState(() => _isSubmitting = false);
                            final err = ref.read(supportProvider).errorMessage;
                            AppFlushbar.error(context, title: 'Failed', message: err ?? 'Could not create ticket.');
                          }
                        },
                  child: (_isSubmitting || supportState.isActionLoading)
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('SUBMIT TICKET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
