import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Foto agen CS ("Riany") di tombol bulat luar — dikonfirmasi dari source
/// HTML asli (`#wap-button > img`, `width:70px;border-radius:50%`, tanpa
/// border/shadow tambahan), bukan tebakan.
const String _kCsButtonAvatarUrl =
    'https://titc.or.id/wp-content/uploads/2025/12/Riany-TITC-Indonesia.gif';

/// Foto di kepala dialog — file BERBEDA dari foto tombol (bukan sekadar
/// crop/zoom dari GIF yang sama seperti sempat dikira). Dikonfirmasi dari
/// `#wap-admin img src`, `width:48px;height:48px;border-radius:50%`.
const String _kCsDialogAvatarUrl =
    'https://titc.or.id/wp-content/uploads/2026/03/7.png';

/// Tombol bulat "Butuh bantuan?" yang muncul di pojok layar Login/Signup,
/// meniru widget WhatsApp popup kustom di web (`#wap-button` di
/// `titc.or.id`, bukan plugin pihak ketiga — kode inline di halaman).
///
/// Nilai (ukuran, URL foto, struktur dialog, placeholder input) disalin
/// PERSIS dari source HTML halaman asli (diunduh & dibaca langsung), bukan
/// tebakan dari screenshot — lihat komentar di tiap bagian untuk potongan
/// aslinya.
///
/// Alur web: klik tombol → form (Nama, Email, WhatsApp, Pesan) → "Kirim
/// Pesan" mengirim data ke `admin-ajax.php?action=wap_save` (simpan lead)
/// LALU membuka WhatsApp lewat `api.whatsapp.com/send` dengan pesan yang
/// sudah terisi.
class WhatsAppHelpButton extends StatelessWidget {
  const WhatsAppHelpButton({super.key});

  static const String _phone = '6285747122171';

  @override
  Widget build(BuildContext context) {
    // Source asli: `<div id="wap-button"><img src="..." style="width:70px;
    // border-radius:50%"></div>` — cuma gambar bulat polos 70px, TIDAK ada
    // border putih atau box-shadow tambahan, dan TIDAK ada label teks
    // terpisah (teks "Butuh bantuan?" yang terlihat melengkung di atas foto
    // itu bagian dari artwork GIF-nya sendiri, bukan HTML/CSS terpisah).
    return GestureDetector(
      onTap: () => _showHelpDialog(context),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: _kCsButtonAvatarUrl,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          memCacheWidth: 210,
          memCacheHeight: 210,
          placeholder: (_, _) => const _CsAvatarFallback(size: 70),
          errorWidget: (_, _, _) => const _CsAvatarFallback(size: 70),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _WapFormDialog());
  }
}

/// Jatuh kembali ke lingkaran biru + ikon headset selama foto masih dimuat,
/// atau kalau gagal diambil.
class _CsAvatarFallback extends StatelessWidget {
  const _CsAvatarFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF29B6F6),
      alignment: Alignment.center,
      child: PhosphorIcon(
        PhosphorIconsRegular.headset,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
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

  /// Status online mengikuti jam yang sama dengan versi web (`updateStatus()`
  /// di source asli): 08:00–20:59 Online, 07:00–07:59 Online soon, sisanya
  /// Offline.
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
    final uri = Uri.parse('https://api.whatsapp.com/send/').replace(
      queryParameters: {'phone': WhatsAppHelpButton._phone, 'text': text},
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusText, statusColor) = _statusInfo;
    // `Theme(data: ThemeData.light())` — dialog aslinya di web SELALU putih
    // (`#wap-box{background:#fff}`), tidak ikut dark mode aplikasi. Tanpa
    // ini, `Dialog`/`TextField` bawaan Flutter otomatis gelap saat dark
    // mode aktif, menyimpang dari referensi web.
    return Theme(
      data: ThemeData.light(),
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          // Source asli: `#wap-box{padding:25px;width:340px}`.
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Butuh bantuan?',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _kCsDialogAvatarUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      memCacheWidth: 144,
                      memCacheHeight: 144,
                      placeholder: (_, _) => const _CsAvatarFallback(size: 48),
                      errorWidget: (_, _, _) =>
                          const _CsAvatarFallback(size: 48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Input web aslinya cuma `placeholder`, TIDAK pakai floating
              // label Material — jadi `hintText`, bukan `labelText`.
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.black87),
                decoration: _fieldDecoration('Nama Lengkap'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: _fieldDecoration('Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _waController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.black87),
                decoration: _fieldDecoration('Nomor WhatsApp'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _msgController,
                maxLines: 3,
                style: const TextStyle(color: Colors.black87),
                decoration: _fieldDecoration('Pesan'),
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
      ),
    );
  }

  /// Meniru `#wap-box input,#wap-box textarea{padding:12px;border:1px solid
  /// #ddd;border-radius:10px}` — placeholder polos, bukan floating label.
  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF22C55E)),
      ),
    );
  }
}
