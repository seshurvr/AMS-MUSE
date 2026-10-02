import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/utils/validators.dart';
import '../../models/class_room.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/class_provider.dart';
import '../../services/image_service.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';

/// Take attendance wizard:
/// Step 1 — class/date/time/subject → creates the session.
/// Step 2 — upload or capture the classroom photo → upload + process.
class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  int _step = 0;
  int? _sessionId;

  // Step 1 form
  final _formKey = GlobalKey<FormState>();
  int? _classId;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final _subject = TextEditingController();
  final _notes = TextEditingController();

  // Step 2
  Uint8List? _pickedBytes;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classes = context.read<ClassProvider>();
      if (classes.classes.isEmpty) classes.load();
    });
    context.read<AttendanceProvider>().clear();
  }

  @override
  void dispose() {
    _subject.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Take attendance')),
      body: provider.loading && _step == 0
          ? const LoadingView(message: 'Creating session…')
          : Stepper(
              currentStep: _step,
              onStepContinue: _onContinue,
              onStepCancel: _step > 0 && !_processing
                  ? () => setState(() => _step -= 1)
                  : null,
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed:
                          _processing ? null : details.onStepContinue,
                      child: Text(_step == 1 ? 'Upload & detect' : 'Continue'),
                    ),
                    const SizedBox(width: 8),
                    if (_step > 0)
                      TextButton(
                        onPressed:
                            _processing ? null : details.onStepCancel,
                        child: const Text('Back'),
                      ),
                  ],
                ),
              ),
              steps: [
                Step(
                  title: const Text('Session details'),
                  isActive: _step >= 0,
                  state: _step > 0
                      ? StepState.complete
                      : StepState.indexed,
                  content: _sessionForm(),
                ),
                Step(
                  title: const Text('Classroom photo'),
                  isActive: _step >= 1,
                  content: _photoStep(provider),
                ),
              ],
            ),
    );
  }

  Widget _sessionForm() {
    final classes = context.watch<ClassProvider>();
    final dateFmt = DateFormat('EEE, dd MMM yyyy');
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _classId,
            decoration: const InputDecoration(
              labelText: 'Class',
              border: OutlineInputBorder(),
            ),
            items: classes.visible
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                          '${c.name} · ${c.section} — ${c.subject}'),
                    ))
                .toList(),
            validator: (v) =>
                v == null ? 'Please select a class.' : null,
            onChanged: (v) => setState(() => _classId = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _date = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(dateFmt.format(_date)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
                    if (picked != null) {
                      setState(() => _time = picked);
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _subject,
            label: 'Subject',
            validator: (v) => Validators.required(v, 'Subject'),
          ),
          AppTextField(
            controller: _notes,
            label: 'Notes (optional)',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _photoStep(AttendanceProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.error != null)
          ErrorView(message: provider.error!),
        if (_pickedBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_pickedBytes!, height: 240,
                fit: BoxFit.cover),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!kIsWeb)
              FilledButton.icon(
                onPressed: _processing ? null : _capture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture photo'),
              ),
            OutlinedButton.icon(
              onPressed: _processing ? null : _pick,
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose photo'),
            ),
          ],
        ),
        if (_processing)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LoadingView(
                message: 'Uploading and detecting faces…'),
          ),
        if (provider.notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(provider.notice!),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _onContinue() async {
    if (_step == 0) {
      if (!_formKey.currentState!.validate()) return;
      final provider = context.read<AttendanceProvider>();
      final session = await provider.createSession(
        classId: _classId!,
        date: _date,
        sessionTime:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        subject: _subject.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(provider.error ?? 'Could not create session.')),
        );
        return;
      }
      setState(() {
        _sessionId = session.id;
        _step = 1;
      });
    } else if (_step == 1) {
      await _uploadAndProcess();
    }
  }

  Future<void> _capture() async {
    final bytes =
        await context.read<ImageService>().captureFromCamera();
    if (bytes != null && mounted) {
      setState(() => _pickedBytes = bytes);
    }
  }

  Future<void> _pick() async {
    final bytes =
        await context.read<ImageService>().pickFromGallery();
    if (bytes != null && mounted) {
      setState(() => _pickedBytes = bytes);
    }
  }

  Future<void> _uploadAndProcess() async {
    if (_pickedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please capture or choose a photo first.')),
      );
      return;
    }
    if (_sessionId == null) return;
    setState(() => _processing = true);
    final provider = context.read<AttendanceProvider>();
    final quality =
        await provider.uploadImage(_sessionId!, _pickedBytes!, 'classroom.jpg');
    if (!mounted) return;
    if (quality == null) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Upload failed.')),
      );
      return;
    }
    final ok = await provider.processSession(_sessionId!);
    if (!mounted) return;
    setState(() => _processing = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Processing failed.')),
      );
      return;
    }
    if (provider.detections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No faces detected in the photo. Try a clearer, brighter photo.')),
      );
    }
    Navigator.of(context).pushReplacementNamed(
      RouteNames.reviewSession(_sessionId!),
    );
  }
}
