import 'package:flutter/material.dart';

import 'widgets/profile_entries.dart';
import 'widgets/profile_function_cards.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_overview_cards.dart';

/// 「我的」页：情侣封面、关键统计与高频入口。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        children: [
          ProfileHeader(),
          SizedBox(height: 16),
          ProfileStatsRow(),
          SizedBox(height: 16),
          ProfileMusicCard(),
          SizedBox(height: 12),
          ProfileSyncEntry(),
          SizedBox(height: 12),
          ProfileFunctionCards(),
          SizedBox(height: 12),
          ProfileAllFeaturesEntry(),
        ],
      ),
    );
  }
}
