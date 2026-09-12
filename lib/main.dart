import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoraSystemApp());
}

// ==========================================
// MODULAR SLOTS & INTERACTION BRIDGES
// ==========================================

abstract class EspBridgeSlot {
  Future<bool> connectBle(String deviceAddress);
  Future<bool> connectWifi(String ipAddress);
  Future<void> sendPayload(String command);
}

class EspHybridBridge implements EspBridgeSlot {
  @override
  Future<bool> connectBle(String deviceAddress) async => true;

  @override
  Future<bool> connectWifi(String ipAddress) async => true;

  @override
  Future<void> sendPayload(String command) async {}
}

abstract class InterAppBridgeSlot {
  Future<List<String>> fetchTodayCalendarEvents();
  Future<void> setSystemAlarm(int hour, int minute, String title);
  void listenMusicLyrics(Function(String song, String lyricLine) onLyric);
}

class AndroidInterAppBridge implements InterAppBridgeSlot {
  @override
  Future<List<String>> fetchTodayCalendarEvents() async {
    return [
      '09:00 - Meeting Proyek N.O.R.A.',
      '14:00 - Check Telemetry ESP32 Node',
    ];
  }

  @override
  Future<void> setSystemAlarm(int hour, int minute, String title) async {}

  @override
  void listenMusicLyrics(Function(String song, String lyricLine) onLyric) {
    Timer.periodic(const Duration(seconds: 4), (timer) {
      onLyric('Metro List Song', 'Baris lirik lagu sedang berjalan...');
    });
  }
}

// ==========================================
// DYNAMIC BUTTON MODEL
// ==========================================

class QuickActionButton {
  String id;
  String label;
  String espCommand;
  IconData icon;

  QuickActionButton({
    required this.id,
    required this.label,
    required this.espCommand,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'espCommand': espCommand,
        'iconCode': icon.codePoint,
      };

  factory QuickActionButton.fromJson(Map<String, dynamic> json) =>
      QuickActionButton(
        id: json['id'],
        label: json['label'],
        espCommand: json['espCommand'],
        icon: IconData(json['iconCode'], fontFamily: 'MaterialIcons'),
      );
}

// ==========================================
// APP ROOT & HUD ENGINE
// ==========================================

class NoraSystemApp extends StatefulWidget {
  const NoraSystemApp({super.key});

  @override
  State<NoraSystemApp> createState() => _NoraSystemAppState();
}

class _NoraSystemAppState extends State<NoraSystemApp> {
  Color _holoColor = const Color(0xFF00F0FF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N.O.R.A. System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF06090F),
        colorScheme: ColorScheme.dark(
          primary: _holoColor,
          surface: const Color(0xFF0D1520),
        ),
      ),
      home: MainHudDashboard(
        holoColor: _holoColor,
        onHoloColorChanged: (c) => setState(() => _holoColor = c),
      ),
    );
  }
}

class MainHudDashboard extends StatefulWidget {
  final Color holoColor;
  final ValueChanged<Color> onHoloColorChanged;

  const MainHudDashboard({
    super.key,
    required this.holoColor,
    required this.onHoloColorChanged,
  });

  @override
  State<MainHudDashboard> createState() => _MainHudDashboardState();
}

class _MainHudDashboardState extends State<MainHudDashboard> {
  int _currentIndex = 0;
  final EspBridgeSlot _espBridge = EspHybridBridge();
  final InterAppBridgeSlot _interApp = AndroidInterAppBridge();

  List<QuickActionButton> _dynamicButtons = [
    QuickActionButton(id: '1', label: 'LAMPU UTAMA', espCommand: 'RELAY_1_TOGGLE', icon: Icons.lightbulb_outline),
    QuickActionButton(id: '2', label: 'KIPAS ANGIN', espCommand: 'FAN_TOGGLE', icon: Icons.air),
    QuickActionButton(id: '3', label: 'MODE MALAM', espCommand: 'SYS_NIGHT', icon: Icons.bedtime),
  ];

  final List<Map<String, String>> _messages = [
    {'sender': 'N.O.R.A.', 'text': 'Jarvis Hologram Interface Ready. All Bridges Online.', 'time': '00:00'}
  ];
  final List<String> _logs = ['[SYSTEM_INIT] Modular Containers Online.'];

  String _currentSong = 'Idle';
  String _currentLyric = 'Menunggu media player...';

  @override
  void initState() {
    super.initState();
    _loadSavedButtons();
    _initLyricsBridge();
  }

  void _initLyricsBridge() {
    _interApp.listenMusicLyrics((song, lyricLine) {
      setState(() {
        _currentSong = song;
        _currentLyric = lyricLine;
      });
    });
  }

  Future<void> _loadSavedButtons() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString('saved_actions');
    if (rawJson != null) {
      final List decoded = jsonDecode(rawJson);
      setState(() {
        _dynamicButtons = decoded.map((e) => QuickActionButton.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveButtons() async {
    final prefs = await SharedPreferences.getInstance();
    final String rawJson = jsonEncode(_dynamicButtons.map((e) => e.toJson()).toList());
    await prefs.setString('saved_actions', rawJson);
  }

  void _addLog(String log) {
    setState(() {
      _logs.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $log');
    });
  }

  void _executeCommand(QuickActionButton btn) {
    _espBridge.sendPayload(btn.espCommand);
    _addLog('Executed Action: ${btn.label} -> ${btn.espCommand}');
    setState(() {
      _messages.add({
        'sender': 'N.O.R.A.',
        'text': 'ESP Payload Executed: [${btn.label}]',
        'time': _getCurrentTime(),
      });
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HoloChatHudTab(
        holoColor: widget.holoColor,
        messages: _messages,
        dynamicButtons: _dynamicButtons,
        currentSong: _currentSong,
        currentLyric: _currentLyric,
        onSendMessage: (txt) {
          setState(() {
            _messages.add({'sender': 'User', 'text': txt, 'time': _getCurrentTime()});
            _messages.add({'sender': 'N.O.R.A.', 'text': 'Processing query: "$txt"', 'time': _getCurrentTime()});
          });
          _addLog('Input: $txt');
        },
        onButtonTap: _executeCommand,
      ),
      ActionBuilderTab(
        holoColor: widget.holoColor,
        buttons: _dynamicButtons,
        onAddButton: (btn) {
          setState(() => _dynamicButtons.add(btn));
          _saveButtons();
          _addLog('New Action Created: ${btn.label}');
        },
        onDeleteButton: (id) {
          setState(() => _dynamicButtons.removeWhere((b) => b.id == id));
          _saveButtons();
          _addLog('Action Deleted: ID $id');
        },
        onHoloColorChanged: widget.onHoloColorChanged,
      ),
      HoloLogsTab(holoColor: widget.holoColor, logs: _logs),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF090E17),
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.radar, color: widget.holoColor, size: 20),
            const SizedBox(width: 8),
            Text('N.O.R.A. HOLO CORE', style: TextStyle(color: widget.holoColor, fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [widget.holoColor.withOpacity(0.08), const Color(0xFF06090F)],
          ),
        ),
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        selectedItemColor: widget.holoColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF090E17),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.blur_on), label: 'HOLO HUD'),
          BottomNavigationBarItem(icon: Icon(Icons.widgets), label: 'ACTION BUILDER'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'DIAGNOSTICS'),
        ],
      ),
    );
  }
}

// ==========================================
// UI HUD & CHAT TAB
// ==========================================

class HoloChatHudTab extends StatelessWidget {
  final Color holoColor;
  final List<Map<String, String>> messages;
  final List<QuickActionButton> dynamicButtons;
  final String currentSong;
  final String currentLyric;
  final Function(String) onSendMessage;
  final Function(QuickActionButton) onButtonTap;

  HoloChatHudTab({
    super.key,
    required this.holoColor,
    required this.messages,
    required this.dynamicButtons,
    required this.currentSong,
    required this.currentLyric,
    required this.onSendMessage,
    required this.onButtonTap,
  });

  final TextEditingController _inputCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // N.O.R.A Custom Logo Header
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: holoColor, width: 2),
              boxShadow: [BoxShadow(color: holoColor.withOpacity(0.5), blurRadius: 12)],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/1000192464.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Lyrics Sync Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1520),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: holoColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.music_note, color: holoColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$currentSong: "$currentLyric"', style: TextStyle(color: holoColor, fontSize: 10, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dynamic Buttons Bar
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: dynamicButtons.length,
            itemBuilder: (context, index) {
              final btn = dynamicButtons[index];
              return Container(
                margin: const EdgeInsets.only(right: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: holoColor.withOpacity(0.6)),
                    backgroundColor: holoColor.withOpacity(0.1),
                  ),
                  icon: Icon(btn.icon, color: holoColor, size: 14),
                  label: Text(btn.label, style: TextStyle(color: holoColor, fontSize: 9)),
                  onPressed: () => onButtonTap(btn),
                ),
              );
            },
          ),
        ),
        // Chat List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final m = messages[index];
              final isNora = m['sender'] == 'N.O.R.A.';
              return Align(
                alignment: isNora ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isNora ? const Color(0xFF0D1520) : holoColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: holoColor.withOpacity(0.4)),
                  ),
                  child: Text('${m['sender']}: ${m['text']}', style: TextStyle(color: isNora ? Colors.white : holoColor, fontSize: 11, fontFamily: 'monospace')),
                ),
              );
            },
          ),
        ),
        // Input Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(icon: Icon(Icons.mic, color: holoColor), onPressed: () {}),
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Perintah Jarvis...',
                    fillColor: const Color(0xFF0D1520),
                    filled: true,
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: holoColor.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: holoColor)),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: holoColor),
                onPressed: () {
                  if (_inputCtrl.text.isNotEmpty) {
                    onSendMessage(_inputCtrl.text);
                    _inputCtrl.clear();
                  }
                },
              )
            ],
          ),
        )
      ],
    );
  }
}

// ==========================================
// ACTION BUILDER & COLOR CUSTOMIZER
// ==========================================

class ActionBuilderTab extends StatelessWidget {
  final Color holoColor;
  final List<QuickActionButton> buttons;
  final Function(QuickActionButton) onAddButton;
  final Function(String) onDeleteButton;
  final ValueChanged<Color> onHoloColorChanged;

  ActionBuilderTab({
    super.key,
    required this.holoColor,
    required this.buttons,
    required this.onAddButton,
    required this.onDeleteButton,
    required this.onHoloColorChanged,
  });

  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _cmdCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('TEMA HOLOGRAM', style: TextStyle(color: holoColor, fontWeight: FontWeight.bold, fontSize: 10)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _colorDot(const Color(0xFF00F0FF)),
            _colorDot(const Color(0xFFFF0055)),
            _colorDot(const Color(0xFF00FF66)),
            _colorDot(const Color(0xFFFFB000)),
          ],
        ),
        const Divider(height: 24),
        Text('DYNAMIC ACTION BUILDER', style: TextStyle(color: holoColor, fontWeight: FontWeight.bold, fontSize: 10)),
        const SizedBox(height: 8),
        TextField(controller: _labelCtrl, decoration: const InputDecoration(labelText: 'Nama Tombol', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _cmdCtrl, decoration: const InputDecoration(labelText: 'Perintah ESP32 (Payload)', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: holoColor),
          onPressed: () {
            if (_labelCtrl.text.isNotEmpty && _cmdCtrl.text.isNotEmpty) {
              onAddButton(QuickActionButton(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                label: _labelCtrl.text.toUpperCase(),
                espCommand: _cmdCtrl.text,
                icon: Icons.flash_on,
              ));
              _labelCtrl.clear();
              _cmdCtrl.clear();
            }
          },
          child: const Text('TAMBAH TOMBOL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        ...buttons.map((btn) => Card(
              color: const Color(0xFF0D1520),
              child: ListTile(
                title: Text(btn.label, style: const TextStyle(fontSize: 12)),
                subtitle: Text(btn.espCommand, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 16), onPressed: () => onDeleteButton(btn.id)),
              ),
            )),
      ],
    );
  }

  Widget _colorDot(Color c) {
    return GestureDetector(
      onTap: () => onHoloColorChanged(c),
      child: CircleAvatar(backgroundColor: c, radius: 12),
    );
  }
}

// ==========================================
// DIAGNOSTICS & LOGS TAB
// ==========================================

class HoloLogsTab extends StatelessWidget {
  final Color holoColor;
  final List<String> logs;

  const HoloLogsTab({super.key, required this.holoColor, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      color: Colors.black,
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) => Text(logs[index], style: TextStyle(color: holoColor, fontSize: 10, fontFamily: 'monospace')),
      ),
    );
  }
}
