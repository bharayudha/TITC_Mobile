import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tombol bulat "Butuh bantuan?" (headset) yang muncul di pojok layar
/// Login/Signup, meniru widget WhatsApp popup kustom di web (`#wap-button`
/// di `titc.or.id`, bukan plugin pihak ketiga — kode inline di halaman).
///
/// Alur web: klik tombol → form (Nama, Email, WhatsApp, Pesan) → "Kirim
/// Pesan" mengirim data ke `admin-ajax.php?action=wap_save` (simpan lead)
/// LALU membuka WhatsApp lewat `api.whatsapp.com/send` dengan pesan yang
/// sudah terisi. Diverifikasi langsung dari source HTML halaman web, bukan
/// tebakan — jadi format parameter & urutan aksinya disalin persis.
class WhatsAppHelpButton extends StatelessWidget {
  const WhatsAppHelpButton({super.key});

  static const String _phone = '6285747122171';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHelpDialog(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFF29B6F6),
          shape: BoxShape.circle,
        ),
        child: const PhosphorIcon(
          PhosphorIconsRegular.headset,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _WapFormDialog());
  }
}

class _WapFormDialog extends StatefulWidget {
  const _WapFormDialog();

  @override
  State<_WapFormDialog> createState() => _WapFormDialogState();
}

class _WapFormDialogState extends State<_WapFormDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _waController = TextEditingController();
  final _msgController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _waController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  /// Status online mengikuti jam yang sama dengan versi web:
  /// 08:00–20:59 Online, 07:00–07:59 Online soon, sisanya Offline.
  (String, Color) get _statusInfo {
    final hour = DateTime.now().hour;
    if (hour >= 8 && hour < 21) return ('Online', const Color(0xFF22C55E));
    if (hour == 7) return ('Online soon', const Color(0xFFF59E0B));
    return ('Offline', const Color(0xFFEF4444));
  }

  Future<void> _send() async {
    setState(() => _isSending = true);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final wa = _waController.text.trim();
    final msg = _msgController.text.trim();

    // Simpan lead ke server, sama seperti wapSend() di web. Fire-and-forget
    // (tidak menunggu/mengecek hasilnya) — persis perilaku web aslinya,
    // dan tetap lanjut buka WhatsApp walau simpan gagal (mis. offline).
    unawaited(
      http
          .get(
            Uri.parse('https://titc.or.id/wp-admin/admin-ajax.php').replace(
              queryParameters: {
                'action': 'wap_save',
                'name': name,
                'email': email,
                'wa': wa,
                'msg': msg,
              },
            ),
          )
          .catchError((_) => http.Response('', 0)),
    );

    final text =
        'Halo kak,\n\nNama: $name\nEmail: $email\nWhatsApp: $wa\n\nPesan:\n$msg';
    final uri = Uri.parse(
      'https://api.whatsapp.com/send/',
    ).replace(queryParameters: {'phone': WhatsAppHelpButton._phone, 'text': text});

    if (!mounted) return;
    Navigator.of(context).pop();
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusText, statusColor) = _statusInfo;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(statusText, style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Butuh bantuan?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _waController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Pesan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kirim Pesan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
