import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/friends_provider.dart';
import '../services/firestore_service.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  List<PublicProfile> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final results =
        await ref.read(friendsProvider.notifier).search(_searchController.text);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsProvider);
    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ref.read(friendsProvider).error == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
        ref.read(friendsProvider.notifier).clearError();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Friends'),
            Tab(
                text:
                    'Requests${state.incomingRequests.isEmpty ? '' : ' (${state.incomingRequests.length})'}'),
            const Tab(text: 'Add Friend'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _friendsList(state),
          _requestsList(state),
          _addFriend(),
        ],
      ),
    );
  }

  Widget _friendsList(FriendsState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final friends = state.accepted;
    if (friends.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline,
        message: 'No friends yet, add someone by username.',
      );
    }
    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (_, index) => _friendTile(friends[index]),
    );
  }

  Widget _requestsList(FriendsState state) {
    if (state.incomingRequests.isEmpty) {
      return const _EmptyState(
        icon: Icons.mark_email_unread_outlined,
        message: 'No pending friend requests.',
      );
    }
    return ListView(
      children: state.incomingRequests
          .map((request) => _requestTile(request))
          .toList(),
    );
  }

  Widget _addFriend() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search username',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
                onPressed: _searching ? null : _search,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _results.isEmpty
                ? const _EmptyState(
                    icon: Icons.person_search,
                    message: 'Search by exact or partial username.',
                  )
                : ListView(
                    children: _results.map(_searchResultTile).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _friendTile(Friendship friendship) {
    final profile = friendship.profile;
    return ListTile(
      leading: _avatar(profile),
      title: Text(profile?.displayName.isNotEmpty == true
          ? profile!.displayName
          : '@${profile?.username ?? 'unknown'}'),
      subtitle: Text('@${profile?.username ?? 'unknown'}'),
      onTap: profile == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FriendProfileScreen(profile: profile),
                ),
              ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'unfriend') {
            ref.read(friendsProvider.notifier).unfriend(friendship);
          } else if (value == 'block' && friendship.otherUid != null) {
            ref.read(friendsProvider.notifier).block(friendship.otherUid!);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'unfriend', child: Text('Unfriend')),
          PopupMenuItem(value: 'block', child: Text('Block')),
        ],
      ),
    );
  }

  Widget _requestTile(Friendship request) {
    final profile = request.profile;
    return ListTile(
      leading: _avatar(profile),
      title: Text('@${profile?.username ?? 'unknown'}'),
      subtitle: Text(profile?.displayName ?? ''),
      trailing: Wrap(
        children: [
          IconButton(
            tooltip: 'Accept',
            icon: const Icon(Icons.check, color: Color(0xFF1DB954)),
            onPressed: () => ref.read(friendsProvider.notifier).accept(request),
          ),
          IconButton(
            tooltip: 'Decline',
            icon: const Icon(Icons.close),
            onPressed: () =>
                ref.read(friendsProvider.notifier).decline(request),
          ),
        ],
      ),
    );
  }

  Widget _searchResultTile(PublicProfile profile) {
    return ListTile(
      leading: _avatar(profile),
      title: Text(profile.displayName.isEmpty
          ? '@${profile.username}'
          : profile.displayName),
      subtitle: Text('@${profile.username}'),
      trailing: FilledButton(
        onPressed: () =>
            ref.read(friendsProvider.notifier).sendRequest(profile.uid),
        child: const Text('Add'),
      ),
    );
  }

  Widget _avatar(PublicProfile? profile) {
    if (profile?.photoURL.isNotEmpty == true) {
      return CircleAvatar(
        backgroundImage: CachedNetworkImageProvider(profile!.photoURL),
      );
    }
    return const CircleAvatar(child: Icon(Icons.person_outline));
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF4A4A4A)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
