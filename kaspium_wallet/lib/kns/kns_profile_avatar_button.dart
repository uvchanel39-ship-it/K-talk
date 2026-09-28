import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'kns_providers.dart';
import 'kns_service.dart';

class KnsProfileAvatarButton extends ConsumerStatefulWidget {
  const KnsProfileAvatarButton({super.key, required this.address});

  final String address;

  @override
  ConsumerState<KnsProfileAvatarButton> createState() =>
      _KnsProfileAvatarButtonState();
}

class _KnsProfileAvatarButtonState
    extends ConsumerState<KnsProfileAvatarButton> {
  bool _saving = false;

  Future<void> _editAvatar() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!widget.address.startsWith('kaspa:')) {
        throw StateError(
          'KNS profile photos are available for mainnet addresses.',
        );
      }
      final profile = await ref.read(knsProfileProvider(widget.address).future);
      if (!mounted) return;
      final assetId = profile?.assetId;
      if (assetId == null) {
        throw StateError('This address does not own a verified KNS domain.');
      }

      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (image == null || !mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update KNS profile photo?'),
          content: const Text(
            'The image will be uploaded to KNS. Publishing its URL uses a commit/reveal transaction: 2 KAS is temporarily locked, 1 KAS and the remaining change return to this address, and network fees apply.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final prepared = KnsService.prepareImageForUpload(
        await image.readAsBytes(),
      );
      final imageUrl = await ref
          .read(knsServiceProvider)
          .uploadProfileImage(
            address: widget.address,
            assetId: assetId,
            imageBytes: prepared,
          );
      final result = await ref
          .read(knsInscriptionServiceProvider)
          .updateProfileField(
            assetId: assetId,
            fieldKey: 'avatarUrl',
            value: imageUrl,
          );

      if (result.verified) {
        ref.invalidate(knsProfileProvider(widget.address));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.verified
                ? 'KNS profile photo updated.'
                : 'Transactions submitted. KNS is still indexing the profile.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile photo: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Edit KNS profile photo',
    onPressed: _saving ? null : _editAvatar,
    icon: _saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.photo_camera_outlined),
  );
}
