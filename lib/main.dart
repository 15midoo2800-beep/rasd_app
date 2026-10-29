import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:excel/excel.dart' as ex;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'plate_parser.dart';
import 'database_helper.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LicensePlateScannerScreen(),
    ));

class LicensePlateScannerScreen extends StatefulWidget {
  const LicensePlateScannerScreen({Key? key}) : super(key: key);

  @override
  State<LicensePlateScannerScreen> createState() => _LicensePlateScannerScreenState();
}

class _LicensePlateScannerScreenState extends State<LicensePlateScannerScreen> {
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _isListening = false;
  String _currentStatusText = "جاري تهيئة الصوت...";
  String _liveSpokenText = "";

  String selectedDistrict = "النهضة";
  String selectedStreet = "ض 1";
  String selectedNote = "بدون ملاحظة";

  List<dynamic> records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _initVosk();
  }

  Future<void> _loadRecords() async {
    final logs = await DatabaseHelper.instance.getLogs();
    setState(() {
      records = List<dynamic>.from(logs);
    });
  }

  Future<void> _initVosk() async {
    try {
      // تحميل الموديل كملف مضغوط zip
      final modelPath = await ModelLoader().loadFromAssets('assets/models/vosk-model-ar.zip');
      _model = await _vosk.createModel(modelPath);

      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
        grammar: PlateParser.getGrammarWords(),
      );

      _speechService = await _vosk.initSpeechService(_recognizer!);

      setState(() {
        _currentStatusText = "اختر الحي والشارع أولاً، ثم ابدأ التسجيل وقل اللوحة وبعدها النوع";
      });

      _speechService!.onPartial().listen((event) {
        final data = jsonDecode(event);
        final partial = data["partial"] ?? "";
        setState(() => _liveSpokenText = partial);

        final parsed = PlateParser.parseStream(partial);
        if (parsed != null && parsed["isComplete"] == true) {
          _handleDetectedPlate(parsed);
        }
      });

      _speechService!.onResult().listen((event) {
        final data = jsonDecode(event);
        final text = data["text"] ?? "";
        final parsed = PlateParser.parseStream(text);
        if (parsed != null && parsed["isComplete"] == true) {
          _handleDetectedPlate(parsed);
        }
      });
    } catch (e) {
      setState(() => _currentStatusText = "خطأ في تهيئة الصوت: $e");
    }
  }

  void _handleDetectedPlate(Map<String, dynamic> parsedData) async {
    String plate = parsedData["plate"];
    String type = parsedData["type"];

    if (records.isNotEmpty && records.first["plate"] == plate) return;

    bool isWanted = await DatabaseHelper.instance.checkIsWanted(plate);

    Map<String, dynamic> newRow = {
      "plate": plate,
      "status": isWanted ? 1 : 0,
      "type": type.isEmpty ? "-" : type,
      "street": selectedStreet,
      "district": selectedDistrict,
      "note": selectedNote == "بدون ملاحظة" ? "-" : selectedNote,
    };

    int id = await DatabaseHelper.instance.insertLog(newRow);
    newRow["id"] = id;

    setState(() {
      records.insert(0, newRow);
      _liveSpokenText = "";
    });

    await _recognizer?.reset();
  }

  void _toggleListening() async {
    if (_speechService == null) return;
    if (_isListening) {
      await _speechService!.stop();
      setState(() {
        _isListening = false;
        _currentStatusText = "متوقف";
      });
    } else {
      await _speechService!.start();
      setState(() {
        _isListening = true;
        _currentStatusText = "يستمع الآن...";
      });
    }
  }

  Future<void> _exportExcel() async {
    var excel = ex.Excel.createExcel();
    ex.Sheet sheet = excel['الرصد الميداني'];
    excel.setDefaultSheet('الرصد الميداني');

    sheet.appendRow([
      ex.TextCellValue('اللوحة'),
      ex.TextCellValue('الحالة'),
      ex.TextCellValue('النوع'),
      ex.TextCellValue('الشارع'),
      ex.TextCellValue('ملاحظات'),
    ]);

    for (var r in records) {
      sheet.appendRow([
        ex.TextCellValue(r['plate'].toString()),
        ex.TextCellValue(r['status'] == 1 ? 'مطلوبة' : 'سليمة'),
        ex.TextCellValue((r['type'] ?? '-').toString()),
        ex.TextCellValue((r['street'] ?? '-').toString()),
        ex.TextCellValue((r['note'] ?? '-').toString()),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/rasd_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير رصد السيارات المطلوبة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    iconSize: 48,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.redAccent : Colors.tealAccent,
                    ),
                    onPressed: _toggleListening,
                  ),
                  const Spacer(),
                  const Text(
                    "SHEEKHA",
                    style: TextStyle(color: Colors.tealAccent, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(_currentStatusText, style: const TextStyle(color: Colors.white70)),
                  if (_liveSpokenText.isNotEmpty)
                    Text(
                      _liveSpokenText,
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                      onPressed: () {},
                      child: Text("الحي: $selectedDistrict", style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                      onPressed: () {},
                      child: Text("الشارع: $selectedStreet", style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                    onPressed: _showNotesDialog,
                    child: const Text("ملاحظات", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    onPressed: _exportExcel,
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text("تصدير إكسل"),
                  ),
                  const Spacer(),
                  Text("عدد السجلات: ${records.length}", style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text("اللوحة", style: TextStyle(color: Colors.white60))),
                  Expanded(flex: 1, child: Text("الحالة", style: TextStyle(color: Colors.white60))),
                  Expanded(flex: 2, child: Text("النوع", style: TextStyle(color: Colors.white60))),
                  Expanded(flex: 2, child: Text("الشارع", style: TextStyle(color: Colors.white60))),
                  Expanded(flex: 2, child: Text("ملاحظات", style: TextStyle(color: Colors.white60))),
                  SizedBox(width: 32),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final row = records[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: index % 2 == 0 ? Colors.transparent : Colors.black12,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            row["plate"].toString(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Icon(
                            row["status"] == 1 ? Icons.check_circle : Icons.remove_circle_outline,
                            color: row["status"] == 1 ? Colors.greenAccent : Colors.white30,
                            size: 20,
                          ),
                        ),
                        Expanded(flex: 2, child: Text((row["type"] ?? "-").toString(), style: const TextStyle(color: Colors.white70))),
                        Expanded(flex: 2, child: Text((row["street"] ?? "-").toString(), style: const TextStyle(color: Colors.white70))),
                        Expanded(flex: 2, child: Text((row["note"] ?? "-").toString(), style: const TextStyle(color: Colors.white70))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () async {
                            await DatabaseHelper.instance.deleteLog(row["id"]);
                            setState(() => records.removeAt(index));
                          },
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("اختر ملاحظة", textAlign: TextAlign.right),
          children: [
            "بدون ملاحظة",
            "برحة يمين",
            "برحة يسار",
            "برحة نهاية الشارع",
            "برحة وسط الشارع",
            "برحة فندق"
          ].map((note) => SimpleDialogOption(
                onPressed: () {
                  setState(() => selectedNote = note);
                  Navigator.pop(context);
                },
                child: Text(note, textAlign: TextAlign.right),
              )).toList(),
        );
      },
    );
  }
}
