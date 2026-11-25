import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'support_provider.dart';
import 'support_model.dart';
import 'raise_ticket_screen.dart';
import 'support_ticket_chat_screen.dart';

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportProvider.notifier).fetchCategories();
      ref.read(supportProvider.notifier).fetchTickets(statusFilter: _selectedFilter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final supportState = ref.watch(supportProvider);
    final tickets = supportState.tickets;
    final counts = supportState.counts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Captain Support & Help'),
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Tickets',
            onPressed: () {
              ref.read(supportProvider.notifier).fetchTickets(statusFilter: _selectedFilter);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Premium Support Hero Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.secondary, Color(0xFF1E427B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 28),
                          SizedBox(width: 10),
                          Text(
                            '24/7 Captain Support Desk',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Text(
                          'SLA 24H',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Raise disputes regarding fare, toll, penalty, or wallet payouts. Our team is here to assist you.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBadge('Total', '${counts.total}'),
                        _buildDividerVertical(),
                        _buildStatBadge('Pending', '${counts.pending}'),
                        _buildDividerVertical(),
                        _buildStatBadge('In Progress', '${counts.inProgress}'),
                        _buildDividerVertical(),
                        _buildStatBadge('Resolved', '${counts.resolved}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Status Filter Chips Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', counts.total),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'pending', counts.pending),
                    const SizedBox(width: 8),
                    _buildFilterChip('In Progress', 'in_progress', counts.inProgress),
                    const SizedBox(width: 8),
                    _buildFilterChip('Resolved', 'resolved', counts.resolved),
                    const SizedBox(width: 8),
                    _buildFilterChip('Closed', 'closed', counts.closed),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Tickets List
            Expanded(
              child: supportState.status == SupportStatus.loading && tickets.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(supportProvider.notifier).fetchTickets(statusFilter: _selectedFilter);
                      },
                      child: tickets.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 100),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), shape: BoxShape.circle),
                                        child: const Icon(Icons.confirmation_number_outlined, size: 54, color: AppColors.secondary),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No support tickets found',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Tap "Raise Ticket" below to submit an issue.',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RaiseTicketScreen()));
                                        },
                                        icon: const Icon(Icons.add_rounded, size: 18),
                                        label: const Text('RAISE NEW TICKET', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: tickets.length,
                              itemBuilder: (context, index) {
                                final ticket = tickets[index];
                                return _buildTicketCard(context, ref, ticket);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RaiseTicketScreen()));
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('RAISE TICKET', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildDividerVertical() {
    return Container(height: 24, width: 1, color: Colors.white24);
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
          ref.read(supportProvider.notifier).fetchTickets(statusFilter: value);
        }
      },
    );
  }

  Widget _buildTicketCard(BuildContext context, WidgetRef ref, SupportTicket ticket) {
    Color badgeColor = Colors.orange;
    final statusKey = ticket.statusBadge.status.toLowerCase();
    if (statusKey == 'resolved' || statusKey == 'success') {
      badgeColor = Colors.green;
    } else if (statusKey == 'in_progress' || statusKey == 'investigation') {
      badgeColor = Colors.blue;
    } else if (statusKey == 'closed') {
      badgeColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SupportTicketChatScreen(ticketId: ticket.id)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.confirmation_num_rounded, size: 14, color: AppColors.secondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ticket.ticketNumber.isNotEmpty ? ticket.ticketNumber : '#${ticket.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      ticket.statusBadge.label.isNotEmpty ? ticket.statusBadge.label : ticket.status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.subject,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  ticket.categoryName.isNotEmpty ? ticket.categoryName : ticket.category,
                  style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ticket.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (ticket.rideId != null && ticket.rideId!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.directions_car_rounded, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Ride: #${ticket.rideId}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      Text(
                        ticket.createdAt.isNotEmpty ? ticket.createdAt.substring(0, 10) : '',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
