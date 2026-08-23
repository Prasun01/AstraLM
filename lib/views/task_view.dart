import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/task_controller.dart';
import '../models/task_model.dart';

class TaskView extends GetView<TaskController> {
  const TaskView({super.key});

  Color _successColor(ThemeData theme) =>
      theme.brightness == Brightness.dark
          ? const Color(0xFF9CD0A8)
          : const Color(0xFF4E7A5A);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Tasks',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: scheme.onSurface)),
      ),
      body: Obx(() {
        if (controller.currentTask.value != null) {
          return _buildTaskDetail(context, controller.currentTask.value!);
        }
        return _buildTaskList(context);
      }),
      floatingActionButton: Obx(() {
        if (controller.currentTask.value != null) return const SizedBox.shrink();
        return FloatingActionButton(
          onPressed: () => _showCreateDialog(context),
          child: const Icon(Icons.add_rounded),
        );
      }),
    );
  }

  Widget _buildTaskList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (controller.tasks.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 60, height: 60,
          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(18)),
          child: Icon(Icons.bolt_rounded, size: 30, color: scheme.primary)),
        const SizedBox(height: 16),
        Text('No Tasks Yet', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: scheme.onSurface)),
        const SizedBox(height: 6),
        Text('Create a task and the AI will plan\nand execute it autonomously', textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 15, color: scheme.onSurfaceVariant)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: controller.tasks.length,
      itemBuilder: (_, i) => _buildTaskCard(context, controller.tasks[i]),
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskModel task) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context, task.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => controller.currentTask.value = task,
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(_statusIcon(task.status), color: statusColor, size: 18)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.goal, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: scheme.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${task.steps.length} steps · ${task.status.toUpperCase()}', style: GoogleFonts.inter(fontSize: 12, letterSpacing: 0.4, color: statusColor, fontWeight: FontWeight.w600)),
          ])),
          IconButton(icon: Icon(Icons.delete_outline_rounded, size: 18, color: scheme.onSurfaceVariant), onPressed: () => controller.deleteTask(task.id)),
        ])),
      ),
    );
  }

  Widget _buildTaskDetail(BuildContext context, TaskModel task) {
    final scheme = Theme.of(context).colorScheme;
    final successColor = _successColor(Theme.of(context));
    return Column(children: [
      // Header
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), child: Row(children: [
        GestureDetector(
          onTap: () => controller.currentTask.value = null,
          child: Container(width: 32, height: 32,
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: scheme.onSurfaceVariant)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(task.goal, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: scheme.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ])),

      // Steps
      Expanded(child: Obx(() {
        final current = controller.currentTask.value;
        if (current == null) return const SizedBox.shrink();
        if (controller.isPlanning.value) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 16),
            Text('AI is planning steps…', style: GoogleFonts.inter(color: scheme.onSurfaceVariant)),
          ]));
        }
        if (current.steps.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.auto_awesome_outlined, size: 32, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No steps generated.', style: GoogleFonts.inter(color: scheme.onSurfaceVariant)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: current.steps.length,
          itemBuilder: (_, i) => _buildStepTile(context, current.steps[i]),
        );
      })),

      // Execute
      Obx(() {
        final current = controller.currentTask.value;
        if (current == null || current.steps.isEmpty) return const SizedBox.shrink();
        if (current.status == 'completed') {
          return Padding(padding: const EdgeInsets.all(24), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_rounded, color: successColor),
            const SizedBox(width: 8),
            Text('Task Completed', style: GoogleFonts.inter(color: successColor, fontWeight: FontWeight.w600)),
          ]));
        }
        if (current.status == 'planning') return const SizedBox.shrink();

        return SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(24), child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.isExecuting.value ? null : () => controller.executeTask(current),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: controller.isExecuting.value
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(controller.isExecuting.value ? 'Executing…' : 'Execute All Steps'),
          ),
        )));
      }),
    ]);
  }

  Widget _buildStepTile(BuildContext context, TaskStep step) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context, step.status);
    final isRunning = step.status == 'running';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRunning ? scheme.primary.withValues(alpha: 0.08) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _stepStatusIcon(context, step.status),
          const SizedBox(width: 12),
          Expanded(child: Text(step.description, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: scheme.onSurface))),
        ]),
        if (step.command != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(12)),
            child: Text(step.command!, style: GoogleFonts.firaCode(fontSize: 12, color: scheme.inversePrimary)),
          ),
        ],
        if (step.output != null && step.output!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(step.output!, style: GoogleFonts.inter(fontSize: 12, color: statusColor), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }

  Widget _stepStatusIcon(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'running': return SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary));
      case 'done': return Icon(Icons.check_circle_rounded, size: 18, color: _successColor(Theme.of(context)));
      case 'failed': return Icon(Icons.error_rounded, size: 18, color: scheme.error);
      default: return Icon(Icons.circle_outlined, size: 18, color: scheme.onSurfaceVariant);
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'running': return scheme.primary;
      case 'completed': case 'done': return _successColor(Theme.of(context));
      case 'failed': return scheme.error;
      default: return scheme.onSurfaceVariant;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'running': return Icons.sync_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'failed': return Icons.error_rounded;
      case 'planning': return Icons.auto_awesome_rounded;
      default: return Icons.circle_outlined;
    }
  }

  void _showCreateDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('New Task', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      content: TextField(
        controller: textCtrl, autofocus: true, maxLines: 3,
        style: GoogleFonts.inter(fontSize: 15),
        decoration: const InputDecoration(hintText: 'Describe what you want the AI to do…'),
      ),
      actions: [
        TextButton(onPressed: () { textCtrl.dispose(); Navigator.pop(ctx); }, child: Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (textCtrl.text.trim().isNotEmpty) { controller.createTask(textCtrl.text.trim()); }
          textCtrl.dispose();
          Navigator.pop(ctx);
        }, child: const Text('Create')),
      ],
    ));
  }
}
