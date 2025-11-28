import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappweb/vietstock_crypto_app.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  // runApp(const MaterialApp(home: AutomationBotPage()));
  runApp(const MaterialApp(home: VietstockCryptoApp()));
}

class AutomationBotPage extends StatefulWidget {
  const AutomationBotPage({super.key});

  @override
  State<AutomationBotPage> createState() => _AutomationBotPageState();
}

class _AutomationBotPageState extends State<AutomationBotPage> {
  InAppWebViewController? webViewController;

  // Automation Status Logs
  List<String> logs = ["Ready to start..."];
  bool isPageLoaded = false;
  String currentUrl = "";

  // Target Configuration
  final String targetUrl = "https://the-internet.herokuapp.com/login";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flutter Web Bot")),
      body: Column(
        children: [
          // 1. The WebView (The Browser)
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
                  initialSettings: InAppWebViewSettings(
                    isInspectable: true, // Allows debugging in Chrome
                    javaScriptEnabled: true,
                  ),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onLoadStop: (controller, url) async {
                    setState(() {
                      isPageLoaded = true;
                      currentUrl = url.toString();
                      _addLog("Page Loaded: $url");
                    });
                  },
                ),
                if (!isPageLoaded)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  ),
              ],
            ),
          ),

          // 2. The Control Panel (Your Automation Logic)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Automation Controls",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Run Auto-Login"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: isPageLoaded
                              ? _runAutoLoginSequence
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text("Reset"),
                          onPressed: () {
                            webViewController?.loadUrl(
                              urlRequest: URLRequest(url: WebUri(targetUrl)),
                            );
                            setState(() {
                              logs.clear();
                              logs.add("Resetting...");
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) => Text(
                        "• ${logs[index]}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- AUTOMATION LOGIC ---

  Future<void> _runAutoLoginSequence() async {
    if (webViewController == null) return;

    try {
      _addLog("STEP 1: Injecting Credentials...");

      // 1. Fill the Username and Password fields
      // We look for elements by ID and set their .value property
      await webViewController?.evaluateJavascript(
        source: """
        document.getElementById('username').value = 'tomsmith';
        document.getElementById('password').value = 'SuperSecretPassword!';
      """,
      );

      // Small delay to mimic human behavior (optional but safer)
      await Future.delayed(const Duration(milliseconds: 500));

      _addLog("STEP 2: Clicking Login Button...");

      // 2. Find the button (using CSS selector) and click it
      await webViewController?.evaluateJavascript(
        source: """
        document.querySelector('button[type="submit"]').click();
      """,
      );

      // 3. Wait for navigation/reload
      _addLog("Waiting for page transition...");
      // In a real app, you might wait for onLoadStop again,
      // but here we wait a fixed time for demonstration.
      await Future.delayed(const Duration(seconds: 2));

      _addLog("STEP 3: Verifying Success...");

      // 4. Scrape the result (The flash message)
      // We use evaluateJavascript returning a result
      var result = await webViewController?.evaluateJavascript(
        source: """
        document.getElementById('flash').innerText;
      """,
      );

      if (result != null &&
          result.toString().contains("You logged into a secure area")) {
        _addLog("SUCCESS! Login verified.");
        _showSuccessDialog();
      } else {
        _addLog("FAILURE: Could not verify login. Text found: $result");
      }
    } catch (e) {
      _addLog("ERROR: $e");
    }
  }

  void _addLog(String message) {
    setState(() {
      logs.insert(0, "${DateTime.now().second}s: $message");
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text("Bot Success 🤖"),
        content: Text(
          "The bot successfully logged in and verified the secure area.",
        ),
      ),
    );
  }
}
