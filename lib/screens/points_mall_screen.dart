import 'package:flutter/material.dart';

class PointsMallScreen extends StatelessWidget {
  final int availablePoints;
  final int consumedPoints;
  final int remainingPoints;

  const PointsMallScreen({
    super.key,
    required this.availablePoints,
    required this.consumedPoints,
    required this.remainingPoints,
  });

  @override
  Widget build(BuildContext context) {
    final rewardIdeas = _rewardIdeas();

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分商城'),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue[50]!,
              Colors.purple[50]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(context),
            const SizedBox(height: 20),
            Text(
              '可兑换灵感',
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ...rewardIdeas.map((idea) => _RewardIdeaTile(idea: idea)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _PointsSummaryTile(
              label: '可用积分',
              value: availablePoints,
              color: Theme.of(context).primaryColor,
              icon: Icons.stars_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PointsSummaryTile(
              label: '已消耗',
              value: consumedPoints,
              color: Colors.orange[400]!,
              icon: Icons.local_fire_department_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PointsSummaryTile(
              label: '剩余积分',
              value: remainingPoints,
              color: Colors.green[500]!,
              icon: Icons.savings_rounded,
            ),
          ),
        ],
      ),
    );
  }

  List<_RewardIdea> _rewardIdeas() {
    return const [
      _RewardIdea(
        title: '精品咖啡券',
        cost: 150,
        description: '午后小憩来一杯，让努力更有仪式感。',
        icon: Icons.local_cafe_rounded,
        color: Color(0xFF6CC4FF),
      ),
      _RewardIdea(
        title: '胶囊学习包',
        cost: 200,
        description: '精选课程/电子书，保持持续成长。',
        icon: Icons.menu_book_rounded,
        color: Color(0xFF8E7CFF),
      ),
      _RewardIdea(
        title: '专注时段兑换券',
        cost: 120,
        description: '解锁番茄钟音效/主题，提高专注力。',
        icon: Icons.timer_rounded,
        color: Color(0xFFFFA26B),
      ),
      _RewardIdea(
        title: '健康补给包',
        cost: 260,
        description: '营养代餐/健身课，给身体一点奖励。',
        icon: Icons.favorite_rounded,
        color: Color(0xFF6DD5B7),
      ),
      _RewardIdea(
        title: '周末灵感体验',
        cost: 320,
        description: '电影票/展览券，拓展生活边界。',
        icon: Icons.local_activity_rounded,
        color: Color(0xFFFF86A7),
      ),
    ];
  }
}

class _PointsSummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _PointsSummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: Colors.grey[900],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardIdea {
  final String title;
  final int cost;
  final String description;
  final IconData icon;
  final Color color;

  const _RewardIdea({
    required this.title,
    required this.cost,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _RewardIdeaTile extends StatelessWidget {
  final _RewardIdea idea;

  const _RewardIdeaTile({required this.idea});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: idea.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(idea.icon, color: idea.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idea.title,
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  idea.description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${idea.cost} 积分',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  '了解详情',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


