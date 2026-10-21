import 'package:flutter/material.dart';

class ReconciliationStepper extends StatelessWidget {
  final int currentStep; // 0: Scan, 1: Count, 2: Balance
  final bool isScanDone;
  final bool isCountDone;
  final bool isReviewedDone;
  final ValueChanged<int>? onStepTapped;

  const ReconciliationStepper({
    super.key,
    required this.currentStep,
    required this.isScanDone,
    required this.isCountDone,
    required this.isReviewedDone,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = [
      _StepData(
        title: '1. Scan Messages',
        subtitle: isScanDone ? 'Scanned' : 'Step 1',
        icon: Icons.mark_email_read_rounded,
        isCompleted: isScanDone,
      ),
      _StepData(
        title: '2. Count Cash',
        subtitle: isCountDone ? 'Counted' : 'Step 2',
        icon: Icons.payments_rounded,
        isCompleted: isCountDone,
      ),
      _StepData(
        title: '3. Balance & Settle',
        subtitle: isReviewedDone ? 'Settled' : 'Step 3',
        icon: Icons.verified_rounded,
        isCompleted: isReviewedDone,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2022) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Expanded(
              child: _buildStepItem(
                context: context,
                index: i,
                data: steps[i],
                isActive: currentStep == i,
                isDark: isDark,
              ),
            ),
            if (i < steps.length - 1)
              Container(
                width: 14,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: steps[i].isCompleted
                    ? const Color(0xFF1E8E3E)
                    : (isDark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required BuildContext context,
    required int index,
    required _StepData data,
    required bool isActive,
    required bool isDark,
  }) {
    Color iconBg;
    Color iconColor;
    Color textColor;

    if (data.isCompleted) {
      iconBg = const Color(0xFF1E8E3E).withValues(alpha: 0.15);
      iconColor = const Color(0xFF1E8E3E);
      textColor = isDark ? const Color(0xFF81C995) : const Color(0xFF137333);
    } else if (isActive) {
      iconBg = const Color(0xFF1A73E8).withValues(alpha: 0.15);
      iconColor = const Color(0xFF1A73E8);
      textColor = isDark ? const Color(0xFF8AB4F8) : const Color(0xFF1A73E8);
    } else {
      iconBg = isDark ? const Color(0xFF2D2F31) : const Color(0xFFE8EAED);
      iconColor = isDark ? const Color(0xFF80868B) : const Color(0xFF5F6368);
      textColor = isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368);
    }

    return InkWell(
      onTap: onStepTapped != null ? () => onStepTapped!(index) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: iconBg,
                  child: Icon(
                    data.isCompleted ? Icons.check_rounded : data.icon,
                    size: 14,
                    color: iconColor,
                  ),
                ),
                if (isActive)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A73E8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              data.title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive || data.isCompleted ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepData {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;

  _StepData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
  });
}
