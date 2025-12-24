import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// Çakışmayı önlemek için Border'ı gizliyoruz
import 'package:excel/excel.dart' hide Border;
import 'package:audioplayers/audioplayers.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Color(0xFF37474F), // Koyu Arka Plan
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
        fontFamily: 'Sans',
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
  // Asıl öğrenci havuzu
  List<String> allStudents = [
    'Ali',
    'Ayşe',
    'Fatma',
    'Mehmet',
    'Can',
    'Zeynep',
    'Elif',
    'Burak',
  ];

  // Ekranda kartlara atanmış karışık liste
  List<String> cardAssignments = [];

  // Hangi kartların açıldığını takip eden liste
  List<bool> cardRevealedState = [];

  final TextEditingController _textController = TextEditingController();
  final AudioPlayer _soundPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Başlangıçta kartları dağıt
    _resetAndShuffleCards();

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
      // Tüm kartları "kapalı" (false) olarak işaretle
      cardRevealedState = List.filled(cardAssignments.length, false);
    });
  }

  void _onCardTapped(int index) {
    // Eğer kart zaten açıksa işlem yapma
    if (cardRevealedState[index]) return;

    // 1. Ses Çal (Kağıt çevirme sesi)
    _playSound('cevirme.mp3');

    // 2. Kartı Aç
    setState(() {
      cardRevealedState[index] = true;
    });

    // 3. İsim Göründükten Sonra Alkış ve Popup (Biraz gecikmeli)
    Future.delayed(const Duration(milliseconds: 600), () {
      _playSound('alkis.mp3');
      _showWinnerDialog(cardAssignments[index]);
    });
  }

  // --- Ses ---
  Future<void> _playSound(String fileName) async {
    await _soundPlayer.stop();
    await _soundPlayer.play(AssetSource('sounds/$fileName'));
  }

  // --- Popup ---
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
              const Icon(Icons.person, size: 80, color: Colors.teal),
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
                child: const Text("TAMAM"),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Excel İşlemleri ---
  Future<void> _loadStartupExcel() async {
    try {
      String exePath = File(Platform.resolvedExecutable).parent.path;
      String filePath = "$exePath/liste.xlsx";
      File autoFile = File(filePath);

      if (await autoFile.exists()) {
        _parseAndLoadExcel(await autoFile.readAsBytes());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Liste Otomatik Yüklendi")),
          );
        }
      }
    } catch (e) {
      print("Oto yükleme hatası: $e");
    }
  }

  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        var file = File(result.files.single.path!);
        _parseAndLoadExcel(file.readAsBytesSync());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Liste Güncellendi")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
    }
  }

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
      break;
    }

    if (newItems.isNotEmpty) {
      setState(() {
        allStudents = newItems;
        _resetAndShuffleCards(); // Yeni liste gelince kartları yeniden dağıt
      });
    }
  }

  void _addStudent() {
    if (_textController.text.trim().isNotEmpty) {
      setState(() {
        allStudents.add(_textController.text.trim());
        _textController.clear();
        _resetAndShuffleCards(); // Yeni kişi eklenince kartları güncelle
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
                  // Çıkış
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.power_settings_new,
                        color: Colors.red,
                        size: 32,
                      ),
                      onPressed: () async => await windowManager.close(),
                      tooltip: "Kapat",
                    ),
                  ),
                  const Divider(),

                  // Kartları Karıştır Butonu (Büyük)
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

                  // Excel Butonu
                  OutlinedButton.icon(
                    onPressed: _importExcel,
                    icon: const Icon(Icons.file_upload),
                    label: const Text("Excel Yükle"),
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
                    "Toplam Kart: ${cardAssignments.length}",
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
              color: const Color(0xFF263238), // Masa örtüsü rengi gibi koyu
              child: cardAssignments.isEmpty
                  ? const Center(
                      child: Text(
                        "Liste Boş",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Kart sayısına göre sütun sayısını dinamik ayarla
                        // Kartlar çok küçük olmasın (min 150px genişlik)
                        int crossAxisCount = (constraints.maxWidth / 180)
                            .floor();
                        if (crossAxisCount < 2) crossAxisCount = 2;

                        return GridView.builder(
                          itemCount: cardAssignments.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio:
                                    0.75, // Kart oranı (Dikey dikdörtgen)
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

// --- 3D ÇEVRİLEN KART WIDGET'I ---
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
    // Parent'tan gelen duruma göre animasyonu tetikle
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _controller.forward();
    } else if (!widget.isRevealed && oldWidget.isRevealed) {
      _controller.reverse(); // Sıfırla (Kartları karıştırınca kapanması için)
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
          // 3D Dönüş Hesabı
          final angle = _animation.value * pi; // 0 ile 180 derece arası

          // Kartın önü mü arkası mı görünüyor?
          // 90 dereceyi (pi/2) geçince arkası (isim) görünmeli
          final isBackVisible = angle >= pi / 2;

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspektif derinliği
            ..rotateY(angle); // Y ekseninde döndür

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBackVisible
                // --- KARTIN ÖN YÜZÜ (İSİM) ---
                // Yazının ters görünmemesi için onu da 180 derece döndürmeliyiz
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
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
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  )
                // --- KARTIN ARKA YÜZÜ (DESEN) ---
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
                            fontSize: 18,
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
