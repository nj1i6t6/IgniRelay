import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/station_supply_repo.dart';
import 'package:ignirelay_app/l10n/l10n_ext.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_controller.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_manage_tab.dart';
import 'package:ignirelay_app/ui/secondary/station_supply_register_tab.dart';

/// Stage 2A：本檔由 god file 拆出後改為 thin shell。
/// data state + business logic 在 [StationSupplyController]；
/// 註冊表單在 [StationSupplyRegisterTab]；管理頁在 [StationSupplyManageTab]。
///
/// 功能：
///   1. 註冊新的據點物資（is_station=true），設定配額與可見區域
///   2. 瀏覽 / 管理已註冊的據點物資
///   3. 查看各用戶的領取額度使用情形
///   4. 手動重設額度
///
/// 權限：需要 L2+ 身分等級
class StationSupplyScreen extends StatefulWidget {
  const StationSupplyScreen({super.key});

  @override
  State<StationSupplyScreen> createState() => _StationSupplyScreenState();
}

class _StationSupplyScreenState extends State<StationSupplyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StationSupplyController? _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      _controller = StationSupplyController(
        eventStore: context.read<EventStore>(),
        decoder: context.read<EventDecoder>(),
        repo: context.read<StationSupplyRepo>(),
        publisher: context.read<EventPublisher>(),
        identity: context.read<IdentityManager>(),
      );
      _controller!.checkAccessAndLoad();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0d0d1a),
        body: Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
      );
    }
    return ChangeNotifierProvider<StationSupplyController>.value(
      value: _controller!,
      child: Consumer<StationSupplyController>(
        builder: (context, c, _) {
          if (!c.checked) {
            return const Scaffold(
              backgroundColor: Color(0xFF0d0d1a),
              body: Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
            );
          }
          if (!c.authorized) return _buildUnauthorized(context, c);
          return _buildAuthorized(context, c);
        },
      ),
    );
  }

  Widget _buildUnauthorized(BuildContext context, StationSupplyController c) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: Text(context.l10n.stationTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              Text(context.l10n.stationAuthRequired, style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                context.l10n.stationAuthCurrentLevel(c.identityLevel),
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.stationAuthDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white30, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorized(BuildContext context, StationSupplyController c) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d1a),
      appBar: AppBar(
        title: Text(context.l10n.stationTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1a1a2e),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          labelColor: Colors.orangeAccent,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: const Icon(Icons.add_business), text: context.l10n.stationTabAdd),
            Tab(icon: const Icon(Icons.inventory_2), text: context.l10n.stationTabManage),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StationSupplyRegisterTab(
            onPublished: () async {
              await c.loadStationItems();
              _tabController.animateTo(1);
            },
          ),
          StationSupplyManageTab(
            items: c.items,
            onRefresh: c.loadStationItems,
          ),
        ],
      ),
    );
  }
}
