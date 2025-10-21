import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderWidget extends StatefulWidget {
  final Function(String audioPath) onAudioRecorded;
  final bool isArabic;
  final bool autoStart;

  const AudioRecorderWidget({
    Key? key,
    required this.onAudioRecorded,
    required this.isArabic,
    this.autoStart = false,
  }) : super(key: key);

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  bool _permissionChecked = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _audioPath;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Try to request permission once when opening the recorder to trigger
    // the system permission dialog on first use.
    _requestMicPermissionOnOpen();
    // If autoStart is requested, try to start recording after a short delay
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final ok = await _ensureMicPermission();
        if (ok && mounted) {
          await _startRecording();
        }
      });
    }
  }

  Future<void> _requestMicPermissionOnOpen() async {
    if (_permissionChecked) return;
    _permissionChecked = true;
    // Request permission silently on open; if denied we don't show dialog
    // here because the user may just be opening the sheet. We'll handle
    // denied/permanentlyDenied when starting recording.
    try {
      await Permission.microphone.request();
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  Future<bool> _ensureMicPermission({bool showDialogOnDenied = true}) async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    // Try requesting permission
    final newStatus = await Permission.microphone.request();
    if (newStatus.isGranted) return true;

    if (!showDialogOnDenied || !mounted) return false;

    // Show a dialog offering Retry (re-request), Open Settings, or Cancel.
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            widget.isArabic ? 'إذن الميكروفون' : 'Microphone Permission',
          ),
          content: Text(
            widget.isArabic
                ? 'يجب تفعيل إذن الميكروفون لتمكين التسجيل. يمكنك إعادة المحاولة أو فتح إعدادات التطبيق.'
                : 'Microphone permission is required to record. You can retry or open app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Retry: request permission again
                final retryStatus = await Permission.microphone.request();
                if (retryStatus.isGranted) {
                  Navigator.of(ctx).pop(true);
                } else {
                  // If still denied, return false and let caller handle further UX
                  Navigator.of(ctx).pop(false);
                }
              },
              child: Text(widget.isArabic ? 'إعادة المحاولة' : 'Retry'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(ctx).pop(false);
              },
              child: Text(
                widget.isArabic ? 'الذهاب للإعدادات' : 'Open Settings',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
            ),
          ],
        );
      },
    );

    if (result == true) return true;

    // After dialog closed (either user chose Cancel/Open Settings or Retry failed), show a snackbar suggestion
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isArabic
                ? 'يجب السماح بالوصول للميكروفون للبدء بالتسجيل.'
                : 'Microphone permission is required to start recording.',
          ),
        ),
      );
    }

    return false;
  }

  Future<void> _startRecording() async {
    try {
      // Ensure microphone permission is granted, otherwise guide user
      final ok = await _ensureMicPermission();
      if (!ok) return;

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _audioPath = filePath;
      });

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isArabic ? 'خطأ في بدء التسجيل' : 'Error starting recording',
          ),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();

      setState(() {
        _isRecording = false;
      });

      if (path != null && path.isNotEmpty) {
        widget.onAudioRecorded(path);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      _timer?.cancel();

      // Delete the audio file
      if (_audioPath != null) {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        _isRecording = false;
        _recordDuration = 0;
        _audioPath = null;
      });

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== Compact recording card (no top handle/title) =====
          const SizedBox(height: 8),

          // Recording indicator
          if (_isRecording) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _formatDuration(_recordDuration),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isArabic ? 'جاري التسجيل...' : 'Recording...',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_none,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isArabic ? 'اضغط للبدء' : 'Tap to start',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],

          const SizedBox(height: 16),

          // Control buttons
          if (_isRecording)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                ElevatedButton.icon(
                  onPressed: _cancelRecording,
                  icon: const Icon(Icons.close),
                  label: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),

                // Stop button
                ElevatedButton.icon(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.check),
                  label: Text(widget.isArabic ? 'إرسال' : 'Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.mic),
              label: Text(widget.isArabic ? 'ابدأ التسجيل' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
