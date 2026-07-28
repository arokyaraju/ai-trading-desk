import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'market/providers/price_alerts_provider.dart';
import 'app/app.dart';
import 'market/providers/fno_movers_provider.dart';
import 'market/providers/market_provider.dart';
import 'market/providers/sector_provider.dart';
import 'trading/live/live_trading_provider.dart';
import 'trading/providers/option_chain_provider.dart';
import 'market/providers/prev_day_level_screener_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MarketProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => PrevDayLevelScreenerProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SectorProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FnoMoversProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => OptionChainProvider(),
        ),
        // Depends on MarketProvider — must come after it in this list.
        // Runs onMarketUpdate() automatically every time MarketProvider
        // notifies (i.e. on every live tick), feeding the live signal engine.
        ChangeNotifierProxyProvider<MarketProvider, LiveTradingProvider>(
          create: (_) => LiveTradingProvider(),
          update: (_, marketProvider, liveProvider) {
            liveProvider ??= LiveTradingProvider();
            liveProvider.onMarketUpdate(marketProvider);
            return liveProvider;
          },
        ),
        // Depends on MarketProvider — must come after it in this list.
        ChangeNotifierProxyProvider<MarketProvider, PriceAlertsProvider>(
          create: (_) => PriceAlertsProvider(),
          update: (_, marketProvider, alertsProvider) {
            alertsProvider ??= PriceAlertsProvider();
            alertsProvider.onMarketUpdate(marketProvider);
            return alertsProvider;
          },
        ),
      ],
      
      child: const MarketWatchApp(),
    ),
  );
}