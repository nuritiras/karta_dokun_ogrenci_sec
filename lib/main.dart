import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// ÖNEMLİ: Excel kütüphanesindeki Border ile Flutter'ınkini karıştırmasın diye gizliyoruz
import 'package:excel/excel.dart' hide Border;
import 'package:audioplayers/audioplayers.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Kiosk Modu Ayarları (Tam Ekran, Başlıksız)
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Color(0xFF263238), // Koyu Arka Plan
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    fullScreen: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const OgrenciSeciciApp());
}

class OgrenciSeciciApp extends StatelessWidget {
  const OgrenciSeciciApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Şans Kartları',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF263238),
        fontFamily: 'Sans', // Pardus uyumlu font
        useMaterial3: false,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Öğrenci Havuzu
  List<String> allStudents = [
    'Öğrenci 1',
    'Öğrenci 2',
    'Öğrenci 3',
    'Öğrenci 4',
  ];

  // Ekrana dağıtılan kartların listesi
  List<String> cardAssignments = [];

  // Kartların açık/kapalı durumu
  List<bool> cardRevealedState = [];

  final TextEditingController _textController = TextEditingController();
  final AudioPlayer _soundPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // İlk açılışta varsayılan listeyi karıştır
    _resetAndShuffleCards();

    // Uygulama açılınca Excel kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStartupExcel();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _soundPlayer.dispose();
    super.dispose();
  }

  // --- KART MANTIĞI ---
  void _resetAndShuffleCards() {
    setState(() {
      // Listeyi kopyala ve karıştır
      cardAssignments = List.from(allStudents)..shuffle();
      // Tüm kartları kapat
      cardRevealedState = List.filled(cardAssignments.length, false);
    });
  }

  void _onCardTapped(int index) {
    if (cardRevealedState[index]) return; // Zaten açıksa işlem yapma

    // 1. Çevirme Sesi
    _playSound('cevirme.mp3');

    // 2. Kartı Aç
    setState(() {
      cardRevealedState[index] = true;
    });

    // 3. Alkış ve Popup (Gecikmeli)
    Future.delayed(const Duration(milliseconds: 600), () {
      _playSound('alkis.mp3');
      _showWinnerDialog(cardAssignments[index]);
    });
  }

  // --- SES ---
  Future<void> _playSound(String fileName) async {
    await _soundPlayer.stop();
    // assets/sounds/ klasöründe olduğundan emin olun
    await _soundPlayer.play(AssetSource('sounds/$fileName'));
  }

  // --- POPUP (SONUÇ EKRANI) ---
  void _showWinnerDialog(String name) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 80, color: Colors.amber),
              const SizedBox(height: 10),
              const Text(
                "ŞANSLI KİŞİ",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  "TAMAM",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- OTOMATİK EXCEL YÜKLEME (MASAÜSTÜ DESTEKLİ) ---
  Future<void> _loadStartupExcel() async {
    try {
      List<String> pathsToCheck = [];

      // 1. Ev Dizinini Bul (/home/kullanici)
      String? home = Platform.environment['HOME'];
      if (home != null) {
        // Pardus (Türkçe) Masaüstü
        pathsToCheck.add("$home/Masaüstü/liste.xlsx");
        // İngilizce Desktop
        pathsToCheck.add("$home/Desktop/liste.xlsx");
      }

      // 2. Uygulamanın Kendi Klasörü
      String exePath = File(Platform.resolvedExecutable).parent.path;
      pathsToCheck.add("$exePath/liste.xlsx");

      File? foundFile;
      String loadedFrom = "";

      // 3. Dosyaları Kontrol Et
      for (String path in pathsToCheck) {
        File f = File(path);
        if (await f.exists()) {
          foundFile = f;
          loadedFrom = path;
          break;
        }
      }

      // 4. Bulunduysa Yükle
      if (foundFile != null) {
        var bytes = await foundFile.readAsBytes();
        _parseAndLoadExcel(bytes);

        if (mounted) {
          String message =
              loadedFrom.contains("Masaüstü") || loadedFrom.contains("Desktop")
              ? "Masaüstündeki liste yüklendi!"
              : "Otomatik liste yüklendi.";

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.teal[700],
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print("Oto yükleme hatası: $e");
    }
  }

  // --- MANUEL EXCEL SEÇME ---
  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        var file = File(result.files.single.path!);
        _parseAndLoadExcel(file.readAsBytesSync());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Liste Başarıyla Güncellendi")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- EXCEL PARSE (OKUMA) ---
  void _parseAndLoadExcel(List<int> bytes) {
    var excel = Excel.decodeBytes(bytes);
    List<String> newItems = [];
    for (var table in excel.tables.keys) {
      for (var row in excel.tables[table]!.rows) {
        if (row.isNotEmpty && row[0] != null) {
          String cellValue = row[0]!.value.toString();
          if (cellValue.trim().isNotEmpty && cellValue != "null") {
            newItems.add(cellValue);
          }
        }
      }
      break; // Sadece ilk sayfa
    }

    if (newItems.isNotEmpty) {
      setState(() {
        allStudents = newItems;
        _resetAndShuffleCards(); // Yeni liste gelince kartları yeniden dağıt
      });
    }
  }

  // --- MANUEL EKLEME ---
  void _addStudent() {
    if (_textController.text.trim().isNotEmpty) {
      setState(() {
        allStudents.add(_textController.text.trim());
        _textController.clear();
        _resetAndShuffleCards();
      });
    }
  }

  // --- ARAYÜZ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // SOL PANEL (KONTROLLER)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Çıkış Butonu (Kiosk Modu İçin Şart)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.power_settings_new,
                        color: Colors.red,
                        size: 32,
                      ),
                      onPressed: () async => await windowManager.close(),
                      tooltip: "Uygulamadan Çık",
                    ),
                  ),
                  const Divider(),

                  // Karıştır Butonu
                  ElevatedButton.icon(
                    onPressed: _resetAndShuffleCards,
                    icon: const Icon(Icons.shuffle, size: 28),
                    label: const Text(
                      "Kartları Karıştır\nve Sıfırla",
                      textAlign: TextAlign.center,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      minimumSize: const Size(double.infinity, 80),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Excel Yükle Butonu
                  OutlinedButton.icon(
                    onPressed: _importExcel,
                    icon: const Icon(Icons.file_upload),
                    label: const Text("Farklı Excel Seç"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),

                  const Spacer(),

                  // Manuel Ekleme
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: "Öğrenci Ekle",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.teal),
                        onPressed: _addStudent,
                      ),
                    ),
                    onSubmitted: (_) => _addStudent(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Toplam: ${cardAssignments.length} Kişi",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // SAĞ PANEL (KART IZGARASI)
          Expanded(
            flex: 8,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF263238), // Masa Örtüsü Rengi
              child: cardAssignments.isEmpty
                  ? const Center(
                      child: Text(
                        "Liste Boş",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Dinamik Sütun Hesabı
                        int crossAxisCount = (constraints.maxWidth / 180)
                            .floor();
                        if (crossAxisCount < 2) crossAxisCount = 2;

                        return GridView.builder(
                          itemCount: cardAssignments.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.75, // Kart Oranı
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                              ),
                          itemBuilder: (context, index) {
                            return FlipCardWidget(
                              name: cardAssignments[index],
                              isRevealed: cardRevealedState[index],
                              onTap: () => _onCardTapped(index),
                              index: index,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3D KART ANİMASYONU ---
class FlipCardWidget extends StatefulWidget {
  final String name;
  final bool isRevealed;
  final VoidCallback onTap;
  final int index;

  const FlipCardWidget({
    super.key,
    required this.name,
    required this.isRevealed,
    required this.onTap,
    required this.index,
  });

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant FlipCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kart durumu değiştiyse animasyonu tetikle
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _controller.forward();
    } else if (!widget.isRevealed && oldWidget.isRevealed) {
      _controller.reverse(); // Kartlar karıştırılınca geri kapat
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // Dönüş Açısı
          final angle = _animation.value * pi;

          // Kartın arkası mı önü mü görünüyor?
          final isBackVisible = angle >= pi / 2;

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 3D Derinlik
            ..rotateY(angle); // Döndürme

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBackVisible
                // --- KARTIN ÖN YÜZÜ (İSİM) ---
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi), // Yazıyı düzelt
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(2, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.teal, width: 4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  )
                // --- KARTIN ARKA YÜZÜ (KAPALI) ---
                : Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00695C), Color(0xFF4DB6AC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 5,
                          offset: Offset(2, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.help_outline,
                          size: 50,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${widget.index + 1}",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}
