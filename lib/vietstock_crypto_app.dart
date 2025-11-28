import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// void main() {
//   runApp(const MaterialApp(
//     debugShowCheckedModeBanner: false,
//     home: VietstockCryptoApp(),
//   ));
// }

// --- DATA MODEL ---
class StockItem {
  final String symbol;
  final String expiry; // Renamed from 'issuer'. Format: dd/MM/yy
  final String lastP;
  final String lastPC;
  final String refP;
  final String stockP;

  final String breakEven;
  final String
  pcToEven; // Note: Site might duplicate this, but we keep the structure
  final String daysToExp;
  final String exerciseP;
  final String stockColor;

  StockItem({
    required this.symbol,
    required this.expiry,
    required this.lastP,
    required this.lastPC,
    required this.refP,
    required this.stockP,
    required this.breakEven,
    required this.pcToEven,
    required this.daysToExp,
    required this.exerciseP,
    required this.stockColor,
  });
}

enum SortState { none, descending, ascending }

class VietstockCryptoApp extends StatefulWidget {
  const VietstockCryptoApp({super.key});

  @override
  State<VietstockCryptoApp> createState() => _VietstockCryptoAppState();
}

class _VietstockCryptoAppState extends State<VietstockCryptoApp> {
  // Data
  List<StockItem> _allStocks = [];
  List<StockItem> _filteredStocks = [];

  // UI State
  double _fontSize = 14.0;
  bool _isLoading = true;
  String _statusMessage = "Initializing...";
  SortState _currentSort = SortState.none;
  SortState _currentSortEven = SortState.none;
  int _gridPageIndex = 0;

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _daysController =
      TextEditingController(); // NEW: Days input

  InAppWebViewController? _webViewController;
  final String url = 'https://banggia.vietstock.vn/bang-gia/chung-quyen';

  @override
  void dispose() {
    _searchController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  // --- HELPERS ---
  double _parsePrice(String priceStr) {
    String clean = priceStr.replaceAll('.', '').replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0;
  }

  // NEW: Parse "dd/MM/yy" to DateTime
  DateTime? _parseExpiryDate(String dateStr) {
    try {
      final parts = dateStr.trim().split('/');
      if (parts.length != 3) return null;
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = 2000 + int.parse(parts[2]); // Assume 20xx
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  // --- FILTER & SORT ---
  void _updateDisplayList() {
    List<StockItem> temp = List.from(_allStocks);

    // 1. Text Filter (Symbol)
    final query = _searchController.text.trim().toUpperCase();
    if (query.isNotEmpty) {
      temp = temp.where((item) {
        return item.symbol.contains(query);
      }).toList();
    }

    // 2. Date Filter (Expiry >= Today + Days)
    final String daysStr = _daysController.text.trim();
    if (daysStr.isNotEmpty) {
      int? daysToAdd = int.tryParse(daysStr);
      if (daysToAdd != null) {
        // Calculate Target Date (strip time)
        // final now = DateTime.now();
        // final today = DateTime(now.year, now.month, now.day);
        // final targetDate = today.add(Duration(days: daysToAdd));

        // temp = temp.where((item) {
        //   DateTime? itemDate = _parseExpiryDate(item.expiry);
        //   if (itemDate == null) return false;
        //   // Keep if itemDate is same or after targetDate
        //   return !itemDate.isBefore(targetDate);
        // }).toList();
        //--------------
        temp = temp.where((item) {
          DateTime? itemDate = _parseExpiryDate(item.expiry);
          if (itemDate == null) return false;

          return daysToAdd <= countWorkingDays(itemDate);
        }).toList();
      }
    }

    // 3. Sort
    if (_currentSort != SortState.none) {
      temp.sort((a, b) {
        double priceA = _parsePrice(a.lastP);
        double priceB = _parsePrice(b.lastP);
        return _currentSort == SortState.ascending
            ? priceA.compareTo(priceB)
            : priceB.compareTo(priceA);
      });
    }

    if (mounted) setState(() => _filteredStocks = temp);

    if (_currentSortEven != SortState.none) {
      temp.sort((a, b) {
        double priceA = _parsePrice(a.pcToEven);
        double priceB = _parsePrice(b.pcToEven);
        return _currentSortEven == SortState.ascending
            ? priceA.compareTo(priceB)
            : priceB.compareTo(priceA);
      });
    }

    if (mounted) setState(() => _filteredStocks = temp);
  }

  void _toggleSort() {
    setState(() {
      if (_currentSort == SortState.none)
        _currentSort = SortState.descending;
      else if (_currentSort == SortState.descending)
        _currentSort = SortState.ascending;
      else
        _currentSort = SortState.none;
      _updateDisplayList();
    });
  }

  void _toggleSortEven() {
    setState(() {
      if (_currentSortEven == SortState.none)
        _currentSortEven = SortState.descending;
      else if (_currentSortEven == SortState.descending)
        _currentSortEven = SortState.ascending;
      else
        _currentSortEven = SortState.none;
      _updateDisplayList();
    });
  }

  void _reloadPage() {
    setState(() {
      _isLoading = true;
      _allStocks.clear();
      _filteredStocks.clear();
      _statusMessage = "Reloading...";
      _currentSort = SortState.none;
    });
    _webViewController?.reload();
  }

  void _toggleGridPage() {
    setState(() => _gridPageIndex = (_gridPageIndex == 0) ? 1 : 0);
  }

  // --- WIDGETS ---
  Widget _buildCell(
    String text,
    int flex, {
    Color? color,
    TextAlign align = TextAlign.left,
    bool isBold = false,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }

  Widget _buildHeaderCell(
    String text,
    int flex, {
    TextAlign align = TextAlign.left,
    VoidCallback? onTap,
    Widget? icon,
  }) {
    Widget content = Row(
      mainAxisAlignment: align == TextAlign.right
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (icon != null) ...[const SizedBox(width: 4), icon],
      ],
    );
    if (onTap != null) content = InkWell(onTap: onTap, child: content);
    return Expanded(flex: flex, child: content);
  }

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Vietstock CW Monitor"),
        backgroundColor: Colors.teal[800],
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. TOP CONTROLS
          _buildControlPanel(isWideScreen),

          // 2. GRID HEADER
          Container(
            color: Colors.teal[50],
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    "Symbol",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: isWideScreen ? 16 : 8,
                  child: isWideScreen
                      ? _buildWideHeader()
                      : _buildMobileHeader(),
                ),
              ],
            ),
          ),

          if (!isWideScreen)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gridPageIndex == 0 ? Colors.teal : Colors.grey[300],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gridPageIndex == 1 ? Colors.teal : Colors.grey[300],
                  ),
                ),
              ],
            ),
          const Divider(height: 1),

          // 3. MAIN LIST
          Expanded(
            child: _filteredStocks.isEmpty
                ? Center(
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text("No items match filter"),
                  )
                : ListView.separated(
                    itemCount: _filteredStocks.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _filteredStocks[index];
                      double currentPrice = _parsePrice(item.lastP);
                      double basicPrice = _parsePrice(item.refP);
                      double stockPrice = _parsePrice(item.stockP);
                      double excercisePrice = _parsePrice(item.exerciseP);
                      Color stockColor = getColorFromString(item.stockColor);
                      Color priceColor = Colors.amber[700]!;
                      if (currentPrice > basicPrice)
                        priceColor = Colors.green;
                      else if (currentPrice < basicPrice)
                        priceColor = Colors.red;

                      Color exercisePColor = Colors.amber[700]!;
                      if (stockPrice > excercisePrice)
                        exercisePColor = Colors.green;
                      else if (stockPrice < excercisePrice)
                        exercisePColor = Colors.red;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            // FROZEN COLUMN: Shows Symbol + Expiry Date
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.symbol,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: _fontSize,
                                    ),
                                  ),
                                  Text(
                                    item.expiry,
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: _fontSize - 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: isWideScreen ? 16 : 8,
                              child: isWideScreen
                                  ? _buildWideRow(
                                      item,
                                      priceColor,
                                      exercisePColor,
                                      stockColor,
                                    )
                                  : _buildMobileRow(
                                      item,
                                      priceColor,
                                      exercisePColor,
                                      stockColor,
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 1, child: _buildHiddenWebView()),
        ],
      ),
    );
  }

  // --- WIDE ---
  Widget _buildWideHeader() {
    return Row(
      children: [
        _buildHeaderCell(
          "Price",
          2,
          align: TextAlign.right,
          onTap: _toggleSort,
          icon: _currentSort == SortState.none
              ? const Icon(Icons.unfold_more, size: 16)
              : Icon(Icons.arrow_upward, size: 16, color: Colors.green),
        ),
        _buildHeaderCell("+/-", 2, align: TextAlign.right),
        _buildHeaderCell("Ref", 2, align: TextAlign.right),
        _buildHeaderCell("Stock", 2, align: TextAlign.right),
        _buildHeaderCell("B.Even", 2, align: TextAlign.right),
        _buildHeaderCell(
          "% To Even",
          2,
          align: TextAlign.right,

          onTap: _toggleSortEven,
          icon: _currentSortEven == SortState.none
              ? const Icon(Icons.unfold_more, size: 16)
              : Icon(Icons.arrow_upward, size: 16, color: Colors.green),
        ),
        _buildHeaderCell("Days To Exp", 2, align: TextAlign.right),
        _buildHeaderCell("Exercise", 2, align: TextAlign.right),
      ],
    );
  }

  Widget _buildWideRow(
    StockItem item,
    Color priceColor,
    Color exercisePColor,
    Color stockColor,
  ) {
    return Row(
      children: [
        _buildCell(
          item.lastP,
          2,
          align: TextAlign.right,
          color: priceColor,
          isBold: true,
        ),
        _buildCell(item.lastPC, 2, align: TextAlign.right, color: priceColor),
        _buildCell(item.refP, 2, align: TextAlign.right),
        _buildCell(item.stockP, 2, align: TextAlign.right, color: stockColor),
        _buildCell(item.breakEven, 2, align: TextAlign.right),
        _buildCell(item.pcToEven, 2, align: TextAlign.right),
        _buildCell(item.daysToExp, 2, align: TextAlign.right),
        _buildCell(
          item.exerciseP,
          2,
          align: TextAlign.right,
          color: exercisePColor,
        ),
      ],
    );
  }

  // --- MOBILE ---
  Widget _buildMobileHeader() {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0)
          setState(() => _gridPageIndex = 1);
        else if (details.primaryVelocity! > 0)
          setState(() => _gridPageIndex = 0);
      },
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: _gridPageIndex == 0
              ? [
                  _buildHeaderCell(
                    "Price",
                    2,
                    align: TextAlign.right,
                    onTap: _toggleSort,
                    icon: _currentSort == SortState.none
                        ? const Icon(
                            Icons.unfold_more,
                            size: 16,
                            color: Colors.grey,
                          )
                        : Icon(
                            _currentSort == SortState.descending
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 16,
                            color: _currentSort == SortState.descending
                                ? Colors.red
                                : Colors.green,
                          ),
                  ),
                  _buildHeaderCell("+/-", 2, align: TextAlign.right),
                  _buildHeaderCell("Ref", 2, align: TextAlign.right),
                  _buildHeaderCell("Stock", 2, align: TextAlign.right),
                ]
              : [
                  _buildHeaderCell("B.Even", 2, align: TextAlign.right),
                  _buildHeaderCell(
                    "% To Even",
                    2,
                    align: TextAlign.right,
                    onTap: _toggleSortEven,
                    icon: _currentSortEven == SortState.none
                        ? const Icon(Icons.unfold_more, size: 16)
                        : Icon(
                            Icons.arrow_upward,
                            size: 16,
                            color: Colors.green,
                          ),
                  ),
                  _buildHeaderCell("Days To Exp", 2, align: TextAlign.right),
                  _buildHeaderCell("Exercise", 2, align: TextAlign.right),
                ],
        ),
      ),
    );
  }

  Widget _buildMobileRow(
    StockItem item,
    Color priceColor,
    Color exercisePColor,
    Color stockColor,
  ) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0)
          setState(() => _gridPageIndex = 1);
        else if (details.primaryVelocity! > 0)
          setState(() => _gridPageIndex = 0);
      },
      behavior: HitTestBehavior.translucent,
      child: Container(
        child: Row(
          children: _gridPageIndex == 0
              ? [
                  _buildCell(
                    item.lastP,
                    2,
                    align: TextAlign.right,
                    color: priceColor,
                    isBold: true,
                  ),
                  _buildCell(
                    item.lastPC,
                    2,
                    align: TextAlign.right,
                    color: priceColor,
                  ),
                  _buildCell(item.refP, 2, align: TextAlign.right),
                  _buildCell(
                    item.stockP,
                    2,
                    align: TextAlign.right,
                    color: stockColor,
                  ),
                ]
              : [
                  _buildCell(item.breakEven, 2, align: TextAlign.right),
                  _buildCell(item.pcToEven, 2, align: TextAlign.right),
                  _buildCell(item.daysToExp, 2, align: TextAlign.right),
                  _buildCell(
                    item.exerciseP,
                    2,
                    align: TextAlign.right,
                    color: exercisePColor,
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(bool isWideScreen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              // Search Symbol
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Symbol...",
                    isDense: true,
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) => _updateDisplayList(),
                ),
              ),
              const SizedBox(width: 8),

              // NEW: Days Input
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Days",
                    isDense: true,
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _updateDisplayList(),
                ),
              ),
              const SizedBox(width: 4),

              // NEW: Filter Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.filter_list_alt, color: Colors.white),
                  onPressed: _updateDisplayList,
                  tooltip: "Filter Expiry",
                ),
              ),

              if (!isWideScreen) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: _toggleGridPage,
                ),
              ],

              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _reloadPage,
              ),
            ],
          ),

          // Slider Row
          Row(
            children: [
              const Text(
                "Size: ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 10,
                  max: 24,
                  divisions: 14,
                  label: _fontSize.round().toString(),
                  onChanged: (val) => setState(() => _fontSize = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent:
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
        preferredContentMode: UserPreferredContentMode.DESKTOP,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        javaScriptEnabled: true,
      ),
      onWebViewCreated: (controller) => _webViewController = controller,
      onLoadStop: (controller, url) => _startScrapingTimer(),
    );
  }

  void _startScrapingTimer() {
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_webViewController == null || !mounted) return;

      const String jsScraper = """
        (function() {
          var rows = document.querySelectorAll('tr'); 
          if (rows.length < 5) return [];

          var data = [];
var col24e = '';
var stockColor = '';

          
          for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
  const ces = row.querySelectorAll('[id^="excercisePrice-"]');
            
              ces.forEach(el => {
 
col24e = el.getAttribute('data-value');
});

const ces2 = row.querySelectorAll('[class^="baseLastP-"]');
            
              ces2.forEach(el => {
 
stockColor = el.getAttribute('class');
});
stockColor = stockColor.split('-').pop();
            var cells = rows[i].getElementsByTagName('td');

            if (cells.length > 15) {
              try {
                  data.push({
                    "col1": cells[1].innerText.trim(),
                    "col2": cells[2].innerText.trim(), // Renamed key to expiry (was issuer)
                    "col8":  cells[8].innerText.trim(),
                    "col9": cells[9].innerText.trim(),
                    "col10":    cells[10].innerText.trim(),
                    "col11": cells[11].innerText.trim(),
                    "col12": cells[12].innerText.trim(), 
                    "col13":     cells[13].innerText.trim(),
                    "col14":  cells[14].innerText.trim(),
                    "col15": cells[15].innerText.trim(), 
                    "col0": cells[0].innerText.trim(),
                   "col3": cells[3].innerText.trim(),
                     "col4": cells[4].innerText.trim(),
                   "col5": cells[5].innerText.trim(),
                    "col6": cells[6].innerText.trim(),
                   "col7": cells[7].innerText.trim(),
                    "col16":    cells[16].innerText.trim(),
                      "col17":    cells[17].innerText.trim(),
                        "col18":    cells[18].innerText.trim(),
                          "col19":    cells[19].innerText.trim(),
                            "col20":    cells[20].innerText.trim(),
                              "col21":    cells[21].innerText.trim(),
                                "col22":    cells[22].innerText.trim(),
                                "col23":    cells[23].innerText.trim(),
                              "col24":    cells[24].innerText.trim(),
                                "col24e":    col24e,
                                "stockColor":    stockColor,
                                "col25":    cells[25].innerText.trim(),
                                 "col26":    cells[26].innerText.trim()
                              
                   
                  });
              } catch(e) {}
            }
          }
          return data;
        })();
      """;
      //  "col27":    cells[27].innerText.trim()
      try {
        var result = await _webViewController!.evaluateJavascript(
          source: jsScraper,
        );

        if (result != null && result is List && result.isNotEmpty) {
          //   print ('---------------------------------------');
          //  for (var i = 0; i < result.length; i++) {
          //    for (var key in result[i].keys) {
          //      print('$key: ${result[i][key]}');
          //    }
          //    print ('---------------------------------------');
          //  }
          //       print ('---------------------------------------');
          List<StockItem> newList = result.map((e) {
            double pcToEven = 0;
            final double? breakEven = double.tryParse(e['col24'] ?? "");
            if (breakEven != null) {
              final double? lastStockP = double.tryParse(e['col23'] ?? "");
              if (lastStockP != null && lastStockP != 0) {
                pcToEven = (breakEven - lastStockP) / lastStockP * 100;
              }
            }
            double exerciseP =
                (double.tryParse(e['col24e'] ?? "") ?? 0.0) / 1000;

            String stockColor = e['stockColor'] ?? "";
            if (stockColor.contains('red')) {
              // exerciseP = 0.0;
            }
            // Color colorStock = getColorFromString(stockColor);
            DateTime? itemDate = _parseExpiryDate(e['col2'] ?? "");
            final int? daysToExp = itemDate == null
                ? null
                : countWorkingDays(itemDate);
            return StockItem(
              symbol: e['col0'] ?? "",
              expiry: e['col2'] ?? "",
              lastP: e['col12'] ?? "",
              lastPC: e['col15'] ?? "",
              refP: e['col3'] ?? "",
              stockP: e['col23'] ?? "",
              breakEven: e['col24'] ?? "",
              daysToExp: daysToExp == null ? "" : daysToExp.toString(),
              pcToEven: pcToEven.toStringAsFixed(2),
              exerciseP: exerciseP.toStringAsFixed(2),
              stockColor: stockColor,
            );
          }).toList();

          if (mounted) {
            setState(() {
              _allStocks = newList;
              _isLoading = false;
              // Re-run filter automatically to preserve user view
              _updateDisplayList();
            });
          }
        }
      } catch (e) {}
    });
  }
}

int countWorkingDays(DateTime endDate) {
  // Ensure we are comparing dates only, ignoring time components for simplicity
  final today = DateTime.now();

  // Set the start date to the beginning of today for accurate comparison
  DateTime startDate = DateTime(today.year, today.month, today.day);

  // Set the end date to the beginning of the specified end date
  endDate = DateTime(endDate.year, endDate.month, endDate.day);

  // Ensure the end date is actually after today
  if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(startDate)) {
    return 0;
  }

  int workingDays = 0;
  DateTime currentDate = startDate;

  // Loop day by day until we reach the endDate
  while (currentDate.isBefore(endDate)) {
    // Check if the current day is NOT Sunday (DateTime.sunday = 7)
    // AND NOT Saturday (DateTime.saturday = 6)
    if (currentDate.weekday != DateTime.sunday &&
        currentDate.weekday != DateTime.saturday) {
      workingDays++;
    }

    // Move to the next day
    currentDate = currentDate.add(const Duration(days: 1));
  }

  return workingDays;
}

/// Returns a Flutter Color object based on a popular 7-color name string.
Color getColorFromString(String colorName) {
  // Normalize the input string to lowercase for case-insensitive comparison
  final lowerCaseName = colorName.toLowerCase();

  switch (lowerCaseName) {
    case 'red':
      return Colors.red;
    case 'orange':
      return Colors.orange;
    case 'yellow':
      return Colors.yellow;
    case 'green':
      return Colors.green;
    case 'blue':
      return Colors.blue;
    case 'indigo':
      // Often used in the 7-color list (ROYGBIV)
      return Colors.indigo;
    case 'violet':
      // Violet or Purple are common names
      return Colors.purple;
    default:
      // Return a default color if the name is not found
      // print('Warning: Color name "$colorName" not recognized. Using default gray.');
      return Colors.black;
  }
}
