import 'package:flutter/material.dart';
import 'audio_recorder_widget.dart';

class MessageInputWidget extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(String)? onSendAudio;
  final bool isLoading;
  final bool isArabic;

  const MessageInputWidget({
    Key? key,
    required this.onSendMessage,
    this.onSendAudio,
    required this.isLoading,
    required this.isArabic,
  }) : super(key: key);

  @override
  State<MessageInputWidget> createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends State<MessageInputWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _textController.text.trim();
    if (message.isNotEmpty && !widget.isLoading) {
      widget.onSendMessage(message);
      _textController.clear();
    }
  }

  void _openAudioRecorder() {
    if (widget.onSendAudio == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AudioRecorderWidget(
        onAudioRecorded: (audioPath) {
          widget.onSendAudio!(audioPath);
        },
        isArabic: widget.isArabic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 8),

      child: SafeArea(
        child: Row(
          children: [
            // منطقة إدخال النص
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    // const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        enabled: !widget.isLoading,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        textDirection: _getTextDirection(),
                        decoration: InputDecoration(
                          hintText: widget.isArabic
                              ? 'اكتب رسالتك هنا...'
                              : 'Type your message here...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Colors.teal[400]!,
                              width: 1,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // زر الميكروفون
            if (widget.onSendAudio != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: widget.isLoading ? Colors.grey[300] : Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.isLoading ? null : _openAudioRecorder,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.mic,
                        color: widget.isLoading
                            ? Colors.grey[500]
                            : Colors.blue[700],
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

            // زر الإرسال
            Container(
              decoration: BoxDecoration(
                color: widget.isLoading ? Colors.grey[400] : Colors.teal,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isLoading ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    child: widget.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(
                            widget.isArabic
                                ? Icons.send_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextDirection _getTextDirection() {
    final text = _textController.text;
    if (text.isEmpty) {
      return widget.isArabic ? TextDirection.rtl : TextDirection.ltr;
    }

    // تحديد اتجاه النص بناءً على المحتوى
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
  }
}
