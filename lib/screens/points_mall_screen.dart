import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../services/app_settings.dart';
import '../services/checkin_service.dart';

class PointsMallScreen extends StatefulWidget {
  final User user;
  final int totalPoints; // 进入页面时的总积分

  const PointsMallScreen({
    super.key,
    required this.user,
    required this.totalPoints,
  });

  @override
  State<PointsMallScreen> createState() => _PointsMallScreenState();
}

class _PointsMallScreenState extends State<PointsMallScreen> {
  late int _remainingPoints;
  late int _consumedPoints;
  final Map<String, DateTime> _rewardExpiry = {};
  final Set<String> _redeemedRewardIds = {};
  bool _isRefreshing = false;
  bool _showNailong = false; // 是否显示奶龙界面

  String? get _equippedRewardId => AppSettings.instance.equippedLoopyId;

  @override
  void initState() {
    super.initState();
    _remainingPoints = widget.totalPoints;
    _consumedPoints = 0;
    _syncRedeemedRewardsFromSettings(useSetState: false);
    _loadRedeemedRewardsFromServer(); // 同步云端兑换记录，避免多端不一致

    // 如果当前已有装扮中的 Loopy，则默认认为已兑换，方便用户进行装扮和取消装扮操作
    final equippedId = _equippedRewardId;
    if (equippedId != null) {
      final settings = AppSettings.instance;
      if (!_redeemedRewardIds.contains(equippedId)) {
        final expiry = settings.equippedLoopyExpiry ?? DateTime.now().add(const Duration(days: 7));
        _rewardExpiry[equippedId] = expiry;
        _redeemedRewardIds.add(equippedId);
        settings.markRewardRedeemed(equippedId, expiry);
      }
    }
    _cleanupExpiredRewards();

    // 加载本月积分消耗总额，用于「已消耗」卡片显示
    _loadConsumedPoints();
  }

  Future<void> _loadConsumedPoints() async {
    try {
      final records = await CheckinService.getPointsHistory(
        userId: widget.user.id,
        type: 'spend',
      );

      int total = 0;
      for (final r in records) {
        final rawAmount = r['amount'];
        int amount;
        if (rawAmount is int) {
          amount = rawAmount;
        } else if (rawAmount is num) {
          amount = rawAmount.toInt();
        } else if (rawAmount is String) {
          amount = int.tryParse(rawAmount) ?? 0;
        } else {
          amount = 0;
        }
        total += amount;
      }

      if (mounted) {
        setState(() {
          _consumedPoints = total;
        });
      }
    } catch (e) {
      // 失败时不影响主流程，只在控制台打印
      // 用户仍可通过明细看到每笔消耗
      // ignore: avoid_print
      print('加载积分消耗总额失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards = _showNailong ? _nailongRewards() : _loopyRewards();
    final categoryTitle = _showNailong ? '可爱的奶龙' : '可爱的 Loopy';

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分商城'),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '清零兑换',
            onPressed: _resetRedeemedRewards,
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _isRefreshing ? null : _refreshData,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    categoryTitle,
                    style: TextStyle(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.pinkAccent, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          _showNailong = !_showNailong;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _showNailong ? '上一页' : '下一页',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.pinkAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showNailong ? Icons.arrow_back : Icons.arrow_forward,
                              size: 16,
                              color: Colors.pinkAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.5,
              ),
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                final reward = rewards[index];
                final expiresAt = _rewardExpiry[reward.id];
                final isRedeemed =
                    expiresAt != null && expiresAt.isAfter(DateTime.now()) && _redeemedRewardIds.contains(reward.id);
                final isEquipped = _equippedRewardId == reward.id;
                return _LoopyRewardCard(
                  reward: reward,
                  isRedeemed: isRedeemed,
                  isEquipped: isEquipped,
                  expiresAt: isRedeemed ? expiresAt : null,
                  onRedeem: () => _handleRedeem(reward),
                  onToggleEquip: isRedeemed ? () => _handleToggleEquip(reward) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    try {
      final latestPoints = await CheckinService.getUserPoints(widget.user.id);
      await _loadConsumedPoints();
      await _loadRedeemedRewardsFromServer(); // 刷新时也同步云端兑换记录
      if (!mounted) return;
      setState(() {
        _remainingPoints = latestPoints;
      });
      _syncRedeemedRewardsFromSettings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('刷新失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _handleRedeem(_LoopyReward reward) async {
    if (_remainingPoints < reward.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('积分不足，无法兑换该装扮~')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认兑换'),
          content: Text('确定使用 ${reward.cost} 积分兑换「${reward.title}」吗？\n有效期 ${reward.validDays} 天。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认兑换'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final result = await CheckinService.redeemReward(
        userId: widget.user.id,
        cost: reward.cost,
        itemName: reward.title,
      );
      final newPoints = (result['points'] as int?) ?? (_remainingPoints - reward.cost);

      final expiry = DateTime.now().add(Duration(days: reward.validDays));
      setState(() {
        _remainingPoints = newPoints;
        _consumedPoints += reward.cost;
        _rewardExpiry[reward.id] = expiry;
        _redeemedRewardIds.add(reward.id);
      });
      AppSettings.instance.markRewardRedeemed(reward.id, expiry);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('兑换成功！剩余积分 $newPoints'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('兑换失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openPointsHistory(String type) {
    final isEarn = type == 'earn';
    final title = isEarn ? '积分获取记录' : '积分消耗记录';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final bottom = mediaQuery.padding.bottom;
        return SizedBox(
          height: mediaQuery.size.height * 0.7,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: bottom > 0 ? bottom : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '仅展示本月的${isEarn ? '积分获取' : '积分消耗'}记录',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: CheckinService.getPointsHistory(
                      userId: widget.user.id,
                      type: type,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            '加载失败：${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      final records = snapshot.data ?? [];
                      if (records.isEmpty) {
                        return Center(
                          child: Text(
                            isEarn ? '本月还没有积分获取记录～' : '本月还没有积分消耗记录～',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = records[index];
                          final date = r['date']?.toString() ?? '';
                          final rawAmount = r['amount'];
                          int amount;
                          if (rawAmount is int) {
                            amount = rawAmount;
                          } else if (rawAmount is num) {
                            amount = rawAmount.toInt();
                          } else if (rawAmount is String) {
                            amount = int.tryParse(rawAmount) ?? 0;
                          } else {
                            amount = 0;
                          }
                          final desc = r['description']?.toString() ?? '';
                          final sign = isEarn ? '+' : '-';
                          final color = isEarn ? Colors.green[600] : Colors.red[600];

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              desc.isNotEmpty ? desc : (isEarn ? '积分获取' : '积分消耗'),
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              date,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            trailing: Text(
                              '$sign$amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleToggleEquip(_LoopyReward reward) {
    final settings = AppSettings.instance;
    final currentId = settings.equippedLoopyId;
    if (currentId == reward.id) {
      settings.clearLoopy();
    } else {
      final expiry = _rewardExpiry[reward.id] ?? DateTime.now().add(Duration(days: reward.validDays));
      settings.equipLoopy(
        id: reward.id,
        assetPath: reward.assetPath,
        expiry: expiry,
      );
    }
    setState(() {});
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
              value: _remainingPoints,
              color: Theme.of(context).primaryColor,
              icon: Icons.stars_rounded,
            onTap: () => _openPointsHistory('earn'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PointsSummaryTile(
              label: '已消耗',
              value: _consumedPoints,
              color: Colors.orange[400]!,
              icon: Icons.local_fire_department_rounded,
            onTap: () => _openPointsHistory('spend'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PointsSummaryTile(
              label: '累积获得积分',
              value: _remainingPoints + _consumedPoints,
              color: Colors.green[500]!,
              icon: Icons.savings_rounded,
            ),
          ),
        ],
      ),
    );
  }

  List<_LoopyReward> _loopyRewards() {
    const basePath = 'assets/images/loopy';
    return List.generate(20, (index) {
      final fileIndex = index + 1;
      final no = fileIndex.toString().padLeft(2, '0');
      return _LoopyReward(
        id: 'loopy$no',
        title: '可爱的 Loopy #$no',
        assetPath: '$basePath/loopy$fileIndex.gif',
        cost: 20,
        validDays: 7,
      );
    });
  }

  List<_LoopyReward> _nailongRewards() {
    const basePath = 'assets/images/nailong';
    return List.generate(20, (index) {
      final fileIndex = index + 1;
      final no = fileIndex.toString().padLeft(2, '0');
      return _LoopyReward(
        id: 'nailong$no',
        title: '可爱的奶龙 #$no',
        assetPath: '$basePath/nailong$fileIndex.gif',
        cost: 20,
        validDays: 7,
      );
    });
  }

  void _syncRedeemedRewardsFromSettings({bool useSetState = true}) {
    final settings = AppSettings.instance;
    settings.purgeExpiredLoopyRewards();
    final saved = settings.redeemedLoopyRewards;
    void apply() {
      _rewardExpiry
        ..clear()
        ..addAll(saved);
      _redeemedRewardIds
        ..clear()
        ..addAll(saved.keys);
      _cleanupExpiredRewards();
    }

    if (useSetState && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _cleanupExpiredRewards() {
    final now = DateTime.now();
    final expiredIds = _rewardExpiry.entries
        .where((entry) => entry.value.isBefore(now))
        .map((entry) => entry.key)
        .toList();
    if (expiredIds.isEmpty) return;
    for (final id in expiredIds) {
      _rewardExpiry.remove(id);
      _redeemedRewardIds.remove(id);
      AppSettings.instance.removeRedeemedReward(id);
    }
  }

  /// 从服务器拉取兑换记录，确保多设备同步
  Future<void> _loadRedeemedRewardsFromServer() async {
    try {
      final records = await CheckinService.getPointsHistory(
        userId: widget.user.id,
        type: 'spend',
      );

      final Map<String, DateTime> serverRewards = {};
      final now = DateTime.now();

      for (final r in records) {
        final desc = (r['description'] ?? '').toString();
        final reward = _matchRewardByDescription(desc);
        if (reward == null) continue;

        final dateStr = r['date']?.toString() ?? '';
        final redeemDate = DateTime.tryParse(dateStr) ?? now;
        final expiry = redeemDate.add(Duration(days: reward.validDays));
        if (expiry.isAfter(now)) {
          // 同一个 reward 取最晚的有效期
          final existing = serverRewards[reward.id];
          if (existing == null || expiry.isAfter(existing)) {
            serverRewards[reward.id] = expiry;
          }
        }
      }

      if (!mounted || serverRewards.isEmpty) return;

      setState(() {
        serverRewards.forEach((id, expiry) {
          final existing = _rewardExpiry[id];
          if (existing == null || expiry.isAfter(existing)) {
            _rewardExpiry[id] = expiry;
          }
          _redeemedRewardIds.add(id);
        });
      });

      // 持久化到本地，离线时也能读取
      final settings = AppSettings.instance;
      serverRewards.forEach((id, expiry) {
        settings.markRewardRedeemed(id, expiry);
      });

      _cleanupExpiredRewards();
    } catch (e) {
      // 云端同步失败时只记录日志，不阻塞主流程
      // ignore: avoid_print
      print('同步云端兑换记录失败: $e');
    }
  }

  /// 根据兑换描述匹配到具体的 reward（Loopy/奶龙）
  _LoopyReward? _matchRewardByDescription(String desc) {
    final match =
        RegExp(r'兑换[:：]?\s*可爱的\s*(Loopy|奶龙)\s*#?0*(\d+)', caseSensitive: false).firstMatch(desc);
    if (match == null) return null;
    final type = match.group(1)?.toLowerCase();
    final index = int.tryParse(match.group(2) ?? '');
    if (index == null || index <= 0) return null;

    final rewards = type == '奶龙' ? _nailongRewards() : _loopyRewards();
    if (index > rewards.length) return null;
    return rewards[index - 1];
  }

  /// 手动清零兑换状态（调试/重置用）
  Future<void> _resetRedeemedRewards() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清零兑换记录'),
          content: const Text('将清除本地已兑换/装扮状态，积分不会回滚，确认吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确认')),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final settings = AppSettings.instance;
    settings.clearLoopy();
    settings.clearAllRedeemedRewards();

    setState(() {
      _redeemedRewardIds.clear();
      _rewardExpiry.clear();
    });
  }
}

class _PointsSummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _PointsSummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
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
        ),
      ),
    );
  }
}

class _LoopyReward {
  final String id;
  final String title;
  final String assetPath;
  final int cost;
  final int validDays;

  const _LoopyReward({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.cost,
    required this.validDays,
  });
}

class _LoopyRewardCard extends StatelessWidget {
  final _LoopyReward reward;
  final bool isRedeemed;
  final bool isEquipped;
  final DateTime? expiresAt;
  final VoidCallback onRedeem;
  final VoidCallback? onToggleEquip;

  const _LoopyRewardCard({
    required this.reward,
    required this.isRedeemed,
    required this.isEquipped,
    required this.expiresAt,
    required this.onRedeem,
    this.onToggleEquip,
  });

  @override
  Widget build(BuildContext context) {
    // 判断是奶龙还是Loopy
    final isNailong = reward.id.startsWith('nailong');
    final cardColor = isNailong ? const Color(0xFFFFF8E1) : const Color(0xFFFFE6F0); // 奶龙浅黄色，Loopy浅粉色
    final shadowColor = isNailong ? Colors.amber.withOpacity(0.08) : Colors.pinkAccent.withOpacity(0.08);
    final accent = isNailong ? Colors.amber[300]! : Colors.pinkAccent[100]!;
    final buttonColor = isNailong ? Colors.orange[400]! : Colors.pinkAccent;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: cardColor,
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
              child: Image.asset(
                reward.assetPath,
                  fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reward.title,
            style: TextStyle(
              color: Colors.grey[900],
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoChip(
                icon: Icons.stars_rounded,
                label: '${reward.cost} 积分',
                color: accent,
              ),
              const SizedBox(height: 6),
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: '有效期 ${reward.validDays} 天',
                color: isNailong ? Colors.orange[300]! : Colors.deepOrangeAccent[100]!,
              ),
              if (expiresAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '到期日期：${DateFormat('yyyy-MM-dd').format(expiresAt!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRedeemed ? Colors.grey[400] : buttonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: isRedeemed ? null : onRedeem,
              child: Text(
                isRedeemed ? '已兑换' : '立即兑换',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          if (isRedeemed && onToggleEquip != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isEquipped ? Colors.grey : buttonColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: onToggleEquip,
                child: Text(
                  isEquipped ? '取消装扮' : '装扮',
                  style: TextStyle(
                    color: isEquipped ? Colors.grey[800] : buttonColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color.lerp(color, Colors.black, 0.35)!,
            ),
          ),
        ],
      ),
    );
  }
}


