import 'package:flutter/material.dart';
import '../theme/dashboard_theme.dart';

class AdminProfilePanel extends StatelessWidget {
  final String email;
  final VoidCallback onTerms;
  const AdminProfilePanel(
      {super.key, required this.email, required this.onTerms});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0))),
            child: Row(children: [
              const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFBBF7D0),
                  child: Icon(Icons.admin_panel_settings,
                      color: DashboardTheme.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Administrator Profile',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DashboardTheme.ink)),
                    const SizedBox(height: 4),
                    Text(email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: DashboardTheme.muted)),
                  ])),
            ]),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFBBF7D0))),
            tileColor: Colors.white,
            leading:
                const Icon(Icons.gavel_rounded, color: DashboardTheme.green),
            title: const Text('Terms and Conditions',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DashboardTheme.ink)),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: DashboardTheme.muted),
            onTap: onTerms,
          ),
        ],
      );
}

class StoreSuppliesButton extends StatelessWidget {
  final VoidCallback onPressed;
  const StoreSuppliesButton({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.storefront_rounded, size: 18),
        label: const Text('Store Supplies',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
            foregroundColor: DashboardTheme.green,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFBBF7D0)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
      );
}

class OrderOptionsButton extends StatelessWidget {
  final bool hasFile;
  final bool canReject;
  final bool canDelete;
  final bool canCancel;
  final ValueChanged<String> onSelected;
  const OrderOptionsButton(
      {super.key,
      required this.hasFile,
      required this.onSelected,
      this.canReject = true,
      this.canDelete = false,
      this.canCancel = false});

  PopupMenuItem<String> item(String value, String label, IconData icon,
      {bool enabled = true, bool destructive = false}) {
    final foreground = destructive
        ? const Color(0xFFBE123C)
        : enabled
            ? DashboardTheme.ink
            : DashboardTheme.muted;
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 48,
      child: Row(children: [
        Icon(icon,
            size: 18,
            color: destructive
                ? const Color(0xFFBE123C)
                : enabled
                    ? DashboardTheme.green
                    : DashboardTheme.muted),
        const SizedBox(width: 10),
        Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(8)),
        child: PopupMenuButton<String>(
          tooltip: 'Order Options',
          icon: const Icon(Icons.more_vert_rounded,
              size: 18, color: DashboardTheme.green),
          padding: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          constraints: const BoxConstraints(minWidth: 230, maxWidth: 280),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFBBF7D0))),
          onSelected: onSelected,
          itemBuilder: (_) => [
            item('review', 'Review Specs & File', Icons.visibility_outlined),
            item('file', 'Open Attached File', Icons.description_outlined,
                enabled: hasFile),
            item('slip', 'Print Job Slip', Icons.print_outlined),
            if (canReject || canDelete || canCancel)
              const PopupMenuDivider(height: 1),
            if (canCancel)
              item('cancel', 'Cancel Order', Icons.cancel_outlined,
                  destructive: true),
            if (canReject)
              item('reject', 'Reject Order', Icons.cancel_outlined,
                  destructive: true),
            if (canDelete)
              item('delete', 'Delete Order', Icons.delete_outline_rounded,
                  destructive: true),
          ],
        ),
      );
}
