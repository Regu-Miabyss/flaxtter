import 'package:flutter/material.dart';
import 'package:flaxtter/models/user.dart';

class UserTile extends StatelessWidget {
  final UserWithExtra user;
  final VoidCallback? onTap;

  const UserTile({
    super.key,
    required this.user,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: user.profileImageUrlHttps != null
            ? NetworkImage(user.profileImageUrlHttps!.replaceAll('normal', '200x200'))
            : null,
        child: user.profileImageUrlHttps == null ? const Icon(Icons.person) : null,
      ),
      title: Text(
        user.name ?? user.screenName ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '@${user.screenName ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
