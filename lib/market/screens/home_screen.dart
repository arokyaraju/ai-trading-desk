import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../fyers/auth/auth_service.dart';
import '../../fyers/rest/fyers_rest_service.dart';
import '../../screens/rrg_screen.dart';
import '../../trading/ui/backtest_screen.dart';
import '../../trading/ui/live_trading_panel.dart';
import '../../trading/ui/trade_journal_panel.dart';
import '../../trading/ui/option_chain_panel.dart';
import '../providers/market_provider.dart';
import '../providers/panel_layout_provider.dart';
import '../widgets/breakout_panel.dart';
import '../widgets/customizable_dashboard.dart';
import '../widgets/fno_heatmap_tab.dart';
import '../widgets/indices_panel.dart';
import '../widgets/movers_panel.dart';
import '../widgets/price_alerts_panel.dart';
import '../widgets/prev_day_level_screener_panel.dart';
import '../widgets/sector_overview_panel.dart';
import '../widgets/status_bar.dart';
import '../widgets/top_bar.dart';
import '../providers/prev_day_level_screener_provider.dart';

class HomeScreen extends StatefulWidget {
  final String? accessToken;

  const HomeScreen({
    super.key,
    this.accessToken,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService authService = AuthService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<MarketProvider>();

      final token = widget.accessToken;

      if (token == null || token.isEmpty) {
        debugPrint("Access token not found.");
        return;
      }

      await provider.loadQuotes();

      provider.connect(token);
    });
  }

  @override
  void dispose() {
    context.read<MarketProvider>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PanelLayoutProvider()..load(),
      child: DefaultTabController(
        length: 6,
        child: Scaffold(
          backgroundColor: const Color(0xff101114),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'backtest',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BacktestScreen()),
              );
            },
            icon: const Icon(Icons.candlestick_chart),
            label: const Text('Backtest'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                TopBar(),
                IndicesPanel(),
                const TabBar(
                  tabs: [
                    Tab(text: 'Trade Journal'),
                    Tab(text: 'Price Alerts'),
                    Tab(text: 'Option Chain'),
                    Tab(text: 'RRG'),
                    Tab(text: 'Heatmap'),
                    Tab(text: 'Screener'),
                  ],
                ),
                SizedBox(
                  height: 260,
                  child: TabBarView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade800),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const TradeJournalPanel(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade800),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const PriceAlertsPanel(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade800),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const OptionChainPanel(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade800),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: RRGScreen(
                            dataProvider: FyersRRGDataProvider(FyersRestService()),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade800),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const FnoHeatmapTab(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade800),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const PrevDayLevelScreenerPanel(),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildLayoutControls(),

                Expanded(
                  child: CustomizableDashboard(
                    panels: {
                      'sector_movers': Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade800),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectorOverviewPanel(),
                              Divider(height: 24),
                              MoversPanel(),
                            ],
                          ),
                        ),
                      ),
                      'live_trading': Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade800),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const LiveTradingPanel(),
                      ),
                      'breakout': Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade800),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const BreakoutPanel(),
                      ),
                    },
                  ),
                ),

                StatusBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutControls() {
    return Consumer<PanelLayoutProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (provider.editMode) ...[
                TextButton.icon(
                  onPressed: provider.resetLayout,
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Reset'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await provider.save();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Layout saved'), duration: Duration(seconds: 1)),
                      );
                    }
                    provider.toggleEditMode();
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save Layout'),
                ),
              ] else
                TextButton.icon(
                  onPressed: provider.toggleEditMode,
                  icon: const Icon(Icons.dashboard_customize, size: 16),
                  label: const Text('Customize'),
                ),
            ],
          ),
        );
      },
    );
  }
}