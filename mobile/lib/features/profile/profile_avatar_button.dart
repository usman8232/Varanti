import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, UserAttributes;
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../data/models/profile_model.dart';

/// Unified top-right circular Profile Photo Avatar button displayed across all
/// main Varanti tabs, with a subtle sync status dot on its ring.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.asData?.value;
    final hairline = AppTheme.hairlineOf(context);
    final surface = Theme.of(context).colorScheme.surface;

    final statusColor = authState.isGuest
        ? AppTheme.statusExpiringSoon
        : AppTheme.statusActive;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Tooltip(
        message: 'Profile & Account',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showProfileAccountSheet(context),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: hairline, width: 1.2),
                  ),
                  child: ClipOval(
                    child: _AvatarImage(
                      profile: profile,
                      isGuest: authState.isGuest,
                      size: 38,
                      fontSize: 13,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showProfileAccountSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ProfileAccountSheet(),
  );
}

class _AvatarImage extends StatelessWidget {
  final UserProfile? profile;
  final bool isGuest;
  final double size;
  final double fontSize;

  const _AvatarImage({
    required this.profile,
    required this.isGuest,
    required this.size,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = AppTheme.subtleSurfaceOf(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final url = profile?.avatarUrl;

    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(subtle, onSurface),
        );
      }
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(subtle, onSurface),
        );
      }
    }

    return _fallback(subtle, onSurface);
  }

  Widget _fallback(Color bg, Color fg) {
    return Container(
      width: size,
      height: size,
      color: bg,
      alignment: Alignment.center,
      child: isGuest && (profile?.fullName == null || profile?.fullName == 'Guest')
          ? Icon(Icons.person_outline_rounded, size: size * 0.52, color: fg)
          : Text(
              profile?.initials ?? 'V',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
    );
  }
}

class _ProfileAccountSheet extends ConsumerStatefulWidget {
  const _ProfileAccountSheet();

  @override
  ConsumerState<_ProfileAccountSheet> createState() =>
      _ProfileAccountSheetState();
}

class _ProfileAccountSheetState extends ConsumerState<_ProfileAccountSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _isUpdating = false;

  Future<String> _saveLocalAvatarCopy(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'varanti_profile'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final dest = p.join(dir.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(sourcePath).copy(dest);
    return dest;
  }

  Future<void> _pickAndUpdatePhoto() async {
    if (_isUpdating) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;

      setState(() => _isUpdating = true);
      final localCopy = await _saveLocalAvatarCopy(picked.path);
      await saveLocalProfileCache(avatarPath: localCopy);

      final authState = ref.read(authProvider);
      final apiClient = ref.read(apiClientProvider);
      if (authState.isAuthenticated && apiClient != null) {
        try {
          await apiClient.uploadAvatar(localCopy);
        } catch (_) {
          // Local avatar copy remains active even if backend API is currently offline
        }
      }

      ref.invalidate(userProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorMessages.friendly(
                e,
                fallback: "Couldn't update your profile photo right now.",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _editDisplayName(String currentName) async {
    final controller = TextEditingController(
      text: currentName == 'Guest' || currentName == 'Varanti User'
          ? ''
          : currentName,
    );
    final nextName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Display Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (nextName == null || nextName.isEmpty) return;
    setState(() => _isUpdating = true);
    try {
      await saveLocalProfileCache(displayName: nextName);
      final authState = ref.read(authProvider);
      final apiClient = ref.read(apiClientProvider);
      if (authState.isAuthenticated) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'full_name': nextName}),
          );
        } catch (_) {}
        if (apiClient != null) {
          try {
            await apiClient.updateProfile(fullName: nextName);
          } catch (_) {}
        }
      }
      ref.invalidate(userProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _handleSignOut(bool isGuest) async {
    Navigator.of(context).pop();
    if (isGuest) {
      await ref.read(authProvider.notifier).signOut();
      return;
    }
    final crimson = AppTheme.crimsonOf(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'Your warranties remain safely backed up in your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: crimson),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final themeMode = ref.watch(themeModeProvider);
    final hairline = AppTheme.hairlineOf(context);
    final subtle = AppTheme.subtleSurfaceOf(context);
    final muted = AppTheme.mutedTextOf(context);
    final crimson = AppTheme.crimsonOf(context);
    final brightness = Theme.of(context).brightness;

    final displayName = profile?.displayLabel ??
        (authState.isGuest ? 'Guest' : (authState.user?.email ?? 'Varanti User'));
    final subtitle = authState.isGuest
        ? 'Receipts stored privately on this device'
        : (profile?.email.isNotEmpty == true
            ? profile!.email
            : (profile?.phone ?? 'Cloud Synced'));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Profile Header with Editable Photo
            Row(
              children: [
                GestureDetector(
                  onTap: _isUpdating ? null : _pickAndUpdatePhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: hairline, width: 1.5),
                        ),
                        child: ClipOval(
                          child: _AvatarImage(
                            profile: profile,
                            isGuest: authState.isGuest,
                            size: 66,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: crimson,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: _isUpdating
                              ? const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 13,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: ShapeDecoration(
                          color: AppTheme.getStatusSoftBg(
                            authState.isGuest ? 'expiring_soon' : 'active',
                            brightness,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          authState.isGuest ? 'Guest Mode' : 'Cloud Synced',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: authState.isGuest
                                ? AppTheme.statusExpiringSoon
                                : AppTheme.statusActive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Name',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _isUpdating ? null : () => _editDisplayName(displayName),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Quick Actions Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_outlined, size: 17),
                    label: const Text('Change Photo', style: TextStyle(fontSize: 13)),
                    onPressed: _isUpdating ? null : _pickAndUpdatePhoto,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 17),
                    label: const Text('Edit Name', style: TextStyle(fontSize: 13)),
                    onPressed: _isUpdating ? null : () => _editDisplayName(displayName),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Appearance Switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: subtle,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickThemePill(
                      label: 'System',
                      icon: Icons.brightness_auto_outlined,
                      selected: themeMode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _QuickThemePill(
                      label: 'Light',
                      icon: Icons.light_mode_outlined,
                      selected: themeMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _QuickThemePill(
                      label: 'Dark',
                      icon: Icons.dark_mode_outlined,
                      selected: themeMode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account Action Button
            if (authState.isGuest)
              FilledButton.icon(
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Sign In to Enable Cloud Sync'),
                onPressed: () => _handleSignOut(true),
              )
            else
              OutlinedButton.icon(
                icon: Icon(Icons.logout_rounded, size: 18, color: crimson),
                label: Text('Sign Out', style: TextStyle(color: crimson)),
                onPressed: () => _handleSignOut(false),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickThemePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _QuickThemePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = AppTheme.mutedTextOf(context);
    final hairline = AppTheme.hairlineOf(context);

    return Material(
      color: selected ? surface : Colors.transparent,
      shape: StadiumBorder(
        side: selected ? BorderSide(color: hairline) : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? onSurface : muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? onSurface : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
