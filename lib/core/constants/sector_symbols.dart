class SectorSymbol {
  final String name;
  final String symbol;

  const SectorSymbol(this.name, this.symbol);
}

class SectorSymbols {
  SectorSymbols._();

  static const List<SectorSymbol> candidates = [
    SectorSymbol("Nifty Bank", "NSE:NIFTYBANK-INDEX"),
    SectorSymbol("Nifty IT", "NSE:NIFTYIT-INDEX"),
    SectorSymbol("Nifty Pharma", "NSE:NIFTYPHARMA-INDEX"),
    SectorSymbol("Nifty Auto", "NSE:NIFTYAUTO-INDEX"),
    SectorSymbol("Nifty FMCG", "NSE:NIFTYFMCG-INDEX"),
    SectorSymbol("Nifty Metal", "NSE:NIFTYMETAL-INDEX"),
    SectorSymbol("Nifty Realty", "NSE:NIFTYREALTY-INDEX"),
    SectorSymbol("Nifty Media", "NSE:NIFTYMEDIA-INDEX"),
    SectorSymbol("Nifty Energy", "NSE:NIFTYENERGY-INDEX"),
    SectorSymbol("Nifty Financial Services", "NSE:FINNIFTY-INDEX"),
    SectorSymbol("Nifty Oil & Gas", "NSE:NIFTYOIL-INDEX"),
  ];
}