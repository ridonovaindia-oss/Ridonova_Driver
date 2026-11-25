import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_flushbar.dart';
import '../emergency_contacts_provider.dart';
import '../models/emergency_contact_model.dart';

class DriverEmergencyContactsScreen extends ConsumerStatefulWidget {
  const DriverEmergencyContactsScreen({super.key});

  @override
  ConsumerState<DriverEmergencyContactsScreen> createState() => _DriverEmergencyContactsScreenState();
}

class _DriverEmergencyContactsScreenState extends ConsumerState<DriverEmergencyContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(emergencyContactsProvider.notifier).fetchContacts();
    });
  }

  void _openContactBottomSheet([EmergencyContactModel? contact]) {
    final state = ref.read(emergencyContactsProvider);
    if (contact == null && state.isMaxReached) {
      AppFlushbar.warning(
        context,
        title: 'Limit Reached',
        message: 'Maximum ${state.maxAllowed} emergency contacts allowed. Delete an existing contact to add a new one.',
      );
      return;
    }

    final isEditing = contact != null;
    final nameController = TextEditingController(text: contact?.name ?? '');
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    String selectedRelation = contact?.relation ?? 'Spouse';
    bool shareRideAutomatically = contact?.shareRideAutomatically ?? false;
    final formKey = GlobalKey<FormState>();

    final relationOptions = ['Parent', 'Spouse', 'Sibling', 'Friend', 'Other'];
    if (!relationOptions.contains(selectedRelation)) {
      selectedRelation = 'Other';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isEditing ? 'Edit Emergency Contact' : 'Add Emergency Contact',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name Field
                      const Text('Contact Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'e.g. Rahul Sharma / Suman',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter contact name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone Field
                      const Text('10-Digit Mobile Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: '9876543210',
                          counterText: '',
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            child: const Text('🇮🇳 +91', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (val) {
                          final clean = (val ?? '').replaceAll(RegExp(r'\D'), '');
                          if (clean.length != 10) {
                            return 'Please enter valid 10-digit number';
                          }
                          if (!RegExp(r'^[6-9]').hasMatch(clean)) {
                            return 'Mobile number must start with 6, 7, 8 or 9';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Relation Dropdown
                      const Text('Relationship', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRelation,
                            isExpanded: true,
                            items: relationOptions.map((rel) {
                              return DropdownMenuItem<String>(
                                value: rel,
                                child: Text(rel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedRelation = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Share Ride Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.share_location_rounded, color: AppColors.primary, size: 22),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Auto-Share Live Ride', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  Text('Send trip tracking SMS to this contact', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Switch(
                              value: shareRideAutomatically,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setModalState(() {
                                  shareRideAutomatically = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            bool success;
                            if (isEditing) {
                              success = await ref.read(emergencyContactsProvider.notifier).updateContact(
                                contact.id,
                                name: nameController.text,
                                phone: phoneController.text,
                                relation: selectedRelation,
                                shareRideAutomatically: shareRideAutomatically,
                              );
                            } else {
                              success = await ref.read(emergencyContactsProvider.notifier).addContact(
                                name: nameController.text,
                                phone: phoneController.text,
                                relation: selectedRelation,
                                shareRideAutomatically: shareRideAutomatically,
                              );
                            }

                            if (context.mounted) {
                              Navigator.pop(bottomSheetContext);
                              final currentState = ref.read(emergencyContactsProvider);
                              if (success) {
                                AppFlushbar.success(
                                  context,
                                  title: isEditing ? 'Contact Updated' : 'Contact Added',
                                  message: currentState.successMessage ?? 'Emergency contact saved successfully.',
                                );
                              } else if (currentState.errorMessage != null) {
                                AppFlushbar.error(
                                  context,
                                  title: 'Save Error',
                                  message: currentState.errorMessage!,
                                );
                              }
                            }
                          },
                          child: Text(
                            isEditing ? 'UPDATE CONTACT' : 'SAVE CONTACT',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteContact(EmergencyContactModel contact) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Remove Contact?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to remove ${contact.name} from your emergency contacts list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await ref.read(emergencyContactsProvider.notifier).deleteContact(contact.id);
              if (mounted) {
                if (success) {
                  AppFlushbar.info(context, title: 'Contact Removed', message: '${contact.name} was removed from emergency list.');
                } else {
                  final err = ref.read(emergencyContactsProvider).errorMessage;
                  if (err != null) {
                    AppFlushbar.error(context, title: 'Error', message: err);
                  }
                }
              }
            },
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emergencyContactsProvider);
    final contacts = state.contacts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency Contacts & SOS'),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Contacts',
            onPressed: () => ref.read(emergencyContactsProvider.notifier).fetchContacts(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(emergencyContactsProvider.notifier).fetchContacts();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Safety Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.shield_rounded, color: AppColors.error, size: 26),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '24x7 Captain Safety & SOS',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Instant SMS & Live GPS alerts during trips',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Add up to ${state.maxAllowed} trusted family members or friends. When you press the SOS button in an emergency, your live location is SMSed to them instantly and our 24x7 Control Room is notified.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), height: 1.4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Counter & Add Contact Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${contacts.length} / ${state.maxAllowed}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: state.isMaxReached ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Contacts Added', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                    InkWell(
                      onTap: state.isMaxReached ? null : () => _openContactBottomSheet(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: state.isMaxReached ? const Color(0xFFE2E8F0) : AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: state.isMaxReached ? const Color(0xFF94A3B8) : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add Contact',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: state.isMaxReached ? const Color(0xFF94A3B8) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. Contacts List
                if (state.isLoading && contacts.isEmpty) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (contacts.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_add_rounded, color: AppColors.primary, size: 36),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Emergency Contacts Yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Add your family or friends to stay protected with one-tap live SOS alerts during active trips.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                        ),
                        const SizedBox(height: 18),
                        InkWell(
                          onTap: () => _openContactBottomSheet(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'ADD FIRST CONTACT',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Column(
                    children: [
                      for (int i = 0; i < contacts.length; i++) ...[
                        _buildContactCard(contacts[i]),
                        if (i < contacts.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // 4. Quick Emergency Helpline Cards
                const Text(
                  'Quick Emergency Helplines (24x7)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),

                // Police Card (112)
                _buildHelplineCard(
                  title: 'Police Emergency (National)',
                  number: '112',
                  subtitle: 'Immediate police response & PCR dispatch',
                  icon: Icons.local_police_rounded,
                  iconColor: const Color(0xFFDC2626),
                  onTap: () => EmergencyContactsNotifier.callPolice(),
                ),

                const SizedBox(height: 8),

                // Ambulance Card (108)
                _buildHelplineCard(
                  title: 'Medical Ambulance Support',
                  number: '108',
                  subtitle: 'Emergency medical assistance & first aid',
                  icon: Icons.emergency_rounded,
                  iconColor: const Color(0xFFEA580C),
                  onTap: () => EmergencyContactsNotifier.callAmbulance(),
                ),

                const SizedBox(height: 8),

                // Captain 24x7 Safety Helpline
                _buildHelplineCard(
                  title: 'Ridonova Captain Safety Helpline',
                  number: '1800 200 8888',
                  subtitle: '24x7 Ridonova Control Room & driver security team',
                  icon: Icons.headset_mic_rounded,
                  iconColor: AppColors.primary,
                  onTap: () => EmergencyContactsNotifier.callCaptainHelpline(),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(EmergencyContactModel contact) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.secondary),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        contact.relation.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  contact.formattedPhone,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                if (contact.shareRideAutomatically) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Auto-share ride live link',
                        style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => EmergencyContactsNotifier.makePhoneCall(contact.phone),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.phone_rounded, color: AppColors.success, size: 20),
                ),
              ),
              InkWell(
                onTap: () => _openContactBottomSheet(contact),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                ),
              ),
              InkWell(
                onTap: () => _confirmDeleteContact(contact),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelplineCard({
    required String title,
    required String number,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
