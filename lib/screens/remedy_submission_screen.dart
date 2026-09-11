import 'package:flutter/material.dart';

import '../services/backend_api.dart';

class RemedySubmissionScreen extends StatefulWidget {
  const RemedySubmissionScreen({required this.api, super.key});

  final BackendApi api;

  @override
  State<RemedySubmissionScreen> createState() => _RemedySubmissionScreenState();
}

class _RemedySubmissionScreenState extends State<RemedySubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  var _submitting = false;

  static const _fields = <(String, String, int)>[
    ('name', 'Remedy or food name', 1),
    ('scientificName', 'Scientific name (optional)', 1),
    ('category', 'Category', 1),
    ('description', 'What is it traditionally used for?', 4),
    ('usage', 'How is it used?', 3),
    ('preparation', 'How is it prepared?', 3),
    ('dosage', 'Dosage or amount guidance', 2),
    ('warning', 'Safety warnings and who should avoid it', 3),
    ('evidenceSource', 'Source or evidence reference', 2),
    ('studyUrl', 'Source URL (optional)', 1),
    ('tags', 'Search tags, separated by commas', 1),
  ];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field.$1] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _controllers[key]!.text.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.api.isConfigured) {
      _showMessage('Contributions require an online API connection.');
      return;
    }
    setState(() => _submitting = true);
    final success = await widget.api.submitRemedy(
      name: _value('name'),
      scientificName: _value('scientificName'),
      category: _value('category'),
      description: _value('description'),
      usage: _value('usage'),
      preparation: _value('preparation'),
      dosage: _value('dosage'),
      warning: _value('warning'),
      evidenceSource: _value('evidenceSource'),
      studyUrl: _value('studyUrl'),
      tags: _value('tags').split(','),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      _showMessage('Submitted for review. It will appear after approval.');
      Navigator.pop(context);
    } else {
      _showMessage('Submission failed. Check your connection and try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contribute a remedy')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text(
              'Share carefully researched traditional or food-based wellness information. Every submission is reviewed before publication.',
            ),
            const SizedBox(height: 16),
            ..._fields.map((field) {
              final optional =
                  field.$1 == 'scientificName' || field.$1 == 'studyUrl';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _controllers[field.$1],
                  minLines: field.$3,
                  maxLines: field.$3 == 1 ? 2 : 5,
                  decoration: InputDecoration(labelText: field.$2),
                  validator: optional
                      ? null
                      : (value) => value == null || value.trim().length < 2
                          ? 'Please provide this information.'
                          : null,
                ),
              );
            }),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_submitting ? 'Submitting...' : 'Submit for review'),
            ),
          ],
        ),
      ),
    );
  }
}
