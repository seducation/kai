import 'package:flutter/material.dart';

class MoreOptionsModal extends StatelessWidget {
  const MoreOptionsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.volume_off),
            title: const Text('Mute'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mute functionality not implemented yet.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Block'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Block functionality not implemented yet.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Report'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report functionality not implemented yet.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
