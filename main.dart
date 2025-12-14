import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  runApp(const GrandparentsMapApp());
}

class GrandparentsMapApp extends StatelessWidget {
  const GrandparentsMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '효도 지도',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        useMaterial3: true,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
          titleLarge: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 20, color: Colors.black87),
        ),
      ),
      home: const GalleryHomeScreen(),
    );
  }
}

// ----------------------------------------------------
// 메인 갤러리 화면 (폴더 선택 + 관리자 모드 진입)
// ----------------------------------------------------

class GalleryHomeScreen extends StatefulWidget {
  const GalleryHomeScreen({super.key});

  @override
  State<GalleryHomeScreen> createState() => _GalleryHomeScreenState();
}

class _GalleryHomeScreenState extends State<GalleryHomeScreen> {
  // 관리자 모드 여부
  bool _isAdminMode = false;

  // 관리자 비밀번호 (일단 '0000'으로 고정)
  final String _adminPassword = '0000';

  void _toggleAdminMode() async {
    if (_isAdminMode) {
      // 이미 관리자 모드면 끄기
      setState(() {
        _isAdminMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 모드가 해제되었습니다.')),
      );
    } else {
      // 관리자 모드 켜기 -> 비밀번호 확인
      await _showPasswordDialog();
    }
  }

  Future<void> _showPasswordDialog() async {
    final TextEditingController passwordController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('관리자 확인'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('사진을 관리하려면 비밀번호를 입력하세요.'),
                const SizedBox(height: 10),
                const Text('초기 비밀번호: 0000',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '비밀번호',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('확인'),
              onPressed: () {
                if (passwordController.text == _adminPassword) {
                  setState(() {
                    _isAdminMode = true;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('관리자 모드로 전환되었습니다. 사진을 등록할 수 있습니다.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비밀번호가 틀렸습니다.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지도 앨범', style: TextStyle(fontSize: 28)),
        centerTitle: true,
        toolbarHeight: 80,
        actions: [
          // 관리자 모드 토글 버튼
          IconButton(
            icon: Icon(
              _isAdminMode ? Icons.lock_open : Icons.lock,
              color: _isAdminMode ? Colors.redAccent : Colors.grey,
              size: 32,
            ),
            onPressed: _toggleAdminMode,
            tooltip: _isAdminMode ? '관리자 모드 끄기' : '관리자 모드 켜기',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (_isAdminMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 20),
                color: Colors.redAccent.withOpacity(0.1),
                child: const Text(
                  '⚠ 관리자 모드입니다. 사진을 추가하거나 삭제할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            const Text(
              '원하시는 항목을\n선택해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, height: 1.4),
            ),
            const SizedBox(height: 20),

            // 1번 폴더: 집 주변 지도 (장소 검색)
            Expanded(
              child: _buildBigFolderCard(
                context,
                title: '집 주변 지도',
                icon: Icons.map,
                color: Colors.orange.shade100,
                iconColor: Colors.deepOrange,
                page: DetailGalleryPage(
                  storageKey: 'images_map', // 저장소 키 (장소 검색)
                  title: '집 주변 지도',
                  description: '집 근처의 약도와\n중요한 장소들입니다.',
                  isAdminMode: _isAdminMode,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2번 폴더: 버스 경로 + 집 to 전철역 (경로 찾기)
            Expanded(
              child: _buildBigFolderCard(
                context,
                title: '버스 및 전철 가는 길',
                icon: Icons.directions_bus,
                color: Colors.blue.shade100,
                iconColor: Colors.blue.shade800,
                page: DetailGalleryPage(
                  storageKey: 'images_transport', // 저장소 키 (경로 찾기)
                  title: '버스 및 전철 가는 길',
                  description: '버스 노선도와\n전철역까지 가는 방법입니다.',
                  isAdminMode: _isAdminMode,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBigFolderCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required Color iconColor,
      required Widget page}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: iconColor),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                '터치하여 보기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 상세 페이지 (이미지 뷰어 + 관리 기능 + 지도 설정)
// ----------------------------------------------------

class DetailGalleryPage extends StatefulWidget {
  final String title;
  final String description;
  final String storageKey;
  final bool isAdminMode;

  const DetailGalleryPage({
    super.key,
    required this.title,
    required this.description,
    required this.storageKey,
    required this.isAdminMode,
  });

  @override
  State<DetailGalleryPage> createState() => _DetailGalleryPageState();
}

class _DetailGalleryPageState extends State<DetailGalleryPage> {
  List<String> _imagePaths = [];
  String _currentDescription = "";
  List<Map<String, dynamic>> _routes = [];

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;

  bool _useWebMapOnly = false;
  bool _suppressWebConfirm = false;

  @override
  void initState() {
    super.initState();
    _currentDescription = widget.description;
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _imagePaths = prefs.getStringList(widget.storageKey) ?? [];
      _currentDescription =
          prefs.getString('${widget.storageKey}_desc') ?? widget.description;

      String? routesJson = prefs.getString('${widget.storageKey}_routes');
      if (routesJson != null) {
        _routes = List<Map<String, dynamic>>.from(jsonDecode(routesJson));
      }

      _suppressWebConfirm = prefs.getBool('suppress_web_confirm') ?? false;
      _useWebMapOnly = prefs.getBool('use_web_map_only') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveImages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(widget.storageKey, _imagePaths);
  }

  Future<void> _saveDescription(String newDescription) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${widget.storageKey}_desc', newDescription);
    setState(() {
      _currentDescription = newDescription;
    });
  }

  Future<void> _saveRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${widget.storageKey}_routes', jsonEncode(_routes));
  }

  Future<void> _toggleMapMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_web_map_only', value);
    setState(() {
      _useWebMapOnly = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(value ? '무조건 인터넷(웹)으로 엽니다.' : '설치된 지도 앱을 선택하여 엽니다.')),
      );
    }
  }

  Future<void> _resetWebSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('suppress_web_confirm');
    await prefs.remove('use_web_map_only');
    setState(() {
      _suppressWebConfirm = false;
      _useWebMapOnly = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 초기화되었습니다.')),
      );
    }
  }

  Future<void> _launchUrlSafe(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앱을 실행할 수 없습니다.')),
        );
      }
    }
  }

  // ------------------------------------------------------------------------
  // 다중 지도 선택 및 실행 로직
  // ------------------------------------------------------------------------
  Future<void> _launchMapAction(Map<String, dynamic> item) async {
    // 1. 로딩 표시 (좌표 계산)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 15),
            Text("위치 정보를 확인 중입니다...",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.none)),
          ],
        ),
      ),
    );

    void closeLoading() {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }

    try {
      String sName = (item['sName'] ?? '').trim();
      String dName = (item['dName'] ?? '').trim();
      String location = (item['location'] ?? '').trim();

      // 좌표 변환
      double? sLat, sLng, dLat, dLng;

      if (widget.storageKey == 'images_transport') {
        if (sName.isNotEmpty) {
          try {
            List<Location> sLocs = await locationFromAddress(sName);
            if (sLocs.isNotEmpty) {
              sLat = sLocs.first.latitude;
              sLng = sLocs.first.longitude;
            }
          } catch (e) {/*무시*/}
        }
        if (dName.isNotEmpty) {
          try {
            List<Location> dLocs = await locationFromAddress(dName);
            if (dLocs.isNotEmpty) {
              dLat = dLocs.first.latitude;
              dLng = dLocs.first.longitude;
            }
          } catch (e) {/*무시*/}
        }
      } else {
        // 장소 검색 모드일 때도 좌표 있으면 좋음
        if (location.isNotEmpty) {
          try {
            List<Location> locs = await locationFromAddress(location);
            if (locs.isNotEmpty) {
              dLat = locs.first.latitude;
              dLng = locs.first.longitude;
            }
          } catch (e) {/*무시*/}
        }
      }

      // ==========================================================
      // 조건 1: 관리자 강제 웹 모드
      // ==========================================================
      if (_useWebMapOnly) {
        closeLoading();
        await _openWebMap(sName, sLat, sLng, dName, dLat, dLng, location);
        return;
      }

      // ==========================================================
      // 조건 2: 지도 앱 선택 메뉴 띄우기
      // ==========================================================
      closeLoading(); // 계산 끝났으니 로딩 닫고 메뉴 준비

      await _showMapSelectionSheet(
        sName: sName,
        sLat: sLat,
        sLng: sLng,
        dName: dName,
        dLat: dLat,
        dLng: dLng,
        location: location,
      );
    } catch (e) {
      closeLoading();
      // 에러 시 웹으로 폴백
      String q = (widget.storageKey == 'images_transport')
          ? (item['dName'] ?? '')
          : (item['location'] ?? '');
      if (mounted)
        await _launchUrlSafe(Uri.parse(
            'https://map.naver.com/p/search/${Uri.encodeComponent(q)}'));
    }
  }

  // ------------------------------------------------------------------------
  // 지도 앱 선택 바텀 시트 (설치된 앱만 보여줌)
  // ------------------------------------------------------------------------
  Future<void> _showMapSelectionSheet(
      {String? sName,
      double? sLat,
      double? sLng,
      String? dName,
      double? dLat,
      double? dLng,
      String? location}) async {
    // URL Scheme 정의
    final bool isTransport = widget.storageKey == 'images_transport';
    final String destName = isTransport ? (dName ?? '') : (location ?? '');

    // 1. 네이버 지도
    Uri naverUrl;
    if (isTransport) {
      String params =
          'nmap://route/public?appname=com.example.grandparents_map';
      if (sLat != null && sLng != null)
        params +=
            '&slat=$sLat&slng=$sLng&sname=${Uri.encodeComponent(sName ?? '')}';
      if (dLat != null && dLng != null)
        params +=
            '&dlat=$dLat&dlng=$dLng&dname=${Uri.encodeComponent(dName ?? '')}';
      else
        params += '&dname=${Uri.encodeComponent(dName ?? '')}';
      naverUrl = Uri.parse(params);
    } else {
      naverUrl = Uri.parse(
          'nmap://search?query=${Uri.encodeComponent(location ?? '')}&appname=com.example.grandparents_map');
    }

    // 2. 카카오맵
    Uri kakaoUrl;
    if (isTransport) {
      // 카카오맵 길찾기: sp(출발), ep(도착), by=PUBLICTRANSIT(대중교통)
      if (sLat != null && sLng != null && dLat != null && dLng != null) {
        kakaoUrl = Uri.parse(
            'kakaomap://route?sp=$sLat,$sLng&ep=$dLat,$dLng&by=PUBLICTRANSIT');
      } else {
        // 좌표 없으면 검색으로 대체
        kakaoUrl = Uri.parse(
            'kakaomap://search?q=${Uri.encodeComponent(dName ?? '')}');
      }
    } else {
      kakaoUrl = Uri.parse(
          'kakaomap://search?q=${Uri.encodeComponent(location ?? '')}');
    }

    // 3. T맵 (주로 운전용이지만 검색 용도로 추가)
    Uri tmapUrl =
        Uri.parse('tmap://search?name=${Uri.encodeComponent(destName)}');

    // 4. 구글맵
    Uri googleUrl;
    if (isTransport && dLat != null && dLng != null) {
      // 구글맵 길찾기 (transit)
      googleUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$dLat,$dLng&travelmode=transit');
      if (sLat != null && sLng != null) {
        googleUrl = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=$sLat,$sLng&destination=$dLat,$dLng&travelmode=transit');
      }
    } else {
      googleUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(destName)}');
    }

    // 설치 여부 확인
    bool hasNaver = await canLaunchUrl(naverUrl);
    bool hasKakao = await canLaunchUrl(kakaoUrl);
    bool hasTmap = await canLaunchUrl(tmapUrl);
    // 구글은 웹 URL 스키마라 보통 다 됨. 앱 있으면 앱으로 열림.

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("어떤 지도로 연결할까요?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (hasNaver)
                _buildMapTile(
                    "네이버 지도", "대중교통, 도보에 강력 추천", Colors.green, Icons.map, () {
                  Navigator.pop(context);
                  _launchUrlSafe(naverUrl);
                }),
              if (hasKakao)
                _buildMapTile(
                    "카카오맵", "깔끔한 길찾기", Colors.yellow.shade700, Icons.near_me,
                    () {
                  Navigator.pop(context);
                  _launchUrlSafe(kakaoUrl);
                }),
              if (hasTmap)
                _buildMapTile("티맵 (TMAP)", "장소 검색 및 운전", Colors.redAccent,
                    Icons.navigation, () {
                  Navigator.pop(context);
                  _launchUrlSafe(tmapUrl);
                }),
              _buildMapTile("구글 지도", "전 세계 공통 지도", Colors.blue, Icons.public,
                  () {
                Navigator.pop(context);
                _launchUrlSafe(googleUrl);
              }),
              const Divider(),
              _buildMapTile("인터넷(웹)으로 열기", "앱이 없어도 됩니다", Colors.grey, Icons.web,
                  () {
                Navigator.pop(context);
                _openWebMap(sName, sLat, sLng, dName, dLat, dLng, location);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapTile(String title, String subtitle, Color color,
      IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 30),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.grey)),
      onTap: onTap,
    );
  }

  // 웹으로 열기 (폴백)
  Future<void> _openWebMap(String? sName, double? sLat, double? sLng,
      String? dName, double? dLat, double? dLng, String? location) async {
    Uri targetUrl;
    if (widget.storageKey == 'images_transport') {
      if (sLat != null && sLng != null && dLat != null && dLng != null) {
        targetUrl = Uri.parse(
            'https://map.naver.com/p/directions/$sLng,$sLat,${Uri.encodeComponent(sName ?? '')}/$dLng,$dLat,${Uri.encodeComponent(dName ?? '')}/transit');
      } else {
        targetUrl = Uri.parse(
            'https://map.naver.com/p/directions/-/-/-/transit?startPlace=${Uri.encodeComponent(sName ?? '')}&goalPlace=${Uri.encodeComponent(dName ?? '')}');
      }
    } else {
      targetUrl = Uri.parse(
          'https://map.naver.com/p/search/${Uri.encodeComponent(location ?? '')}');
    }
    await _launchUrlSafe(targetUrl);
  }

  // (이하 기존 다이얼로그 및 이미지 관리 함수들 - 변경 없음)
  Future<void> _editDescriptionDialog() async {
    final TextEditingController controller =
        TextEditingController(text: _currentDescription);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('설명 수정'),
          content: TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(border: OutlineInputBorder())),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            ElevatedButton(
                onPressed: () {
                  _saveDescription(controller.text);
                  Navigator.pop(context);
                },
                child: const Text('저장')),
          ],
        );
      },
    );
  }

  Future<void> _addOrEditRouteDialog({int? index}) async {
    bool isTransportMode = widget.storageKey == 'images_transport';
    Map<String, dynamic> initialData = index != null
        ? _routes[index]
        : (isTransportMode
            ? {'name': '', 'sName': '', 'dName': ''}
            : {'name': '', 'location': ''});

    final nameController = TextEditingController(text: initialData['name']);
    final sNameController = TextEditingController(text: initialData['sName']);
    final dNameController = TextEditingController(text: initialData['dName']);
    final locationController =
        TextEditingController(text: initialData['location']);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? '추가' : '수정'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '버튼 이름')),
                if (isTransportMode) ...[
                  TextField(
                      controller: sNameController,
                      decoration: const InputDecoration(labelText: '출발지 주소')),
                  TextField(
                      controller: dNameController,
                      decoration: const InputDecoration(labelText: '도착지 주소')),
                ] else ...[
                  TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: '장소 주소')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            ElevatedButton(
                onPressed: () {
                  setState(() {
                    Map<String, dynamic> data = isTransportMode
                        ? {
                            'name': nameController.text,
                            'sName': sNameController.text,
                            'dName': dNameController.text
                          }
                        : {
                            'name': nameController.text,
                            'location': locationController.text
                          };
                    if (index == null)
                      _routes.add(data);
                    else
                      _routes[index] = data;
                  });
                  _saveRoutes();
                  Navigator.pop(context);
                },
                child: const Text('저장')),
          ],
        );
      },
    );
  }

  Future<void> _deleteRoute(int index) async {
    setState(() {
      _routes.removeAt(index);
    });
    _saveRoutes();
  }

  Future<void> _addImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String savedPath =
            path.join(directory.path, path.basename(pickedFile.path));
        await File(pickedFile.path).copy(savedPath);
        setState(() {
          _imagePaths.add(savedPath);
        });
        await _saveImages();
      }
    } catch (e) {}
  }

  Future<void> _deleteImage(int index) async {
    setState(() {
      _imagePaths.removeAt(index);
    });
    await _saveImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 26)),
        toolbarHeight: 70,
        actions: [
          if (widget.isAdminMode) ...[
            IconButton(
                icon: const Icon(Icons.settings_backup_restore,
                    color: Colors.red),
                onPressed: _resetWebSettings),
            IconButton(
                icon: const Icon(Icons.edit_note, size: 32, color: Colors.blue),
                onPressed: _editDescriptionDialog),
          ],
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: widget.isAdminMode
          ? FloatingActionButton.extended(
              onPressed: _addImage,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('사진 추가'),
              backgroundColor: Colors.teal)
          : null,
      body: Column(
        children: [
          if (widget.isAdminMode)
            Container(
              color: Colors.blueGrey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: SwitchListTile(
                secondary: Icon(
                    _useWebMapOnly ? Icons.public : Icons.map_outlined,
                    color: _useWebMapOnly ? Colors.blue : Colors.deepPurple),
                title: const Text('지도 실행 방식',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle:
                    Text(_useWebMapOnly ? '무조건 인터넷으로 열기' : '실행 시 지도 앱 선택하기'),
                value: _useWebMapOnly,
                onChanged: _toggleMapMode,
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.teal.withOpacity(0.1),
            child: Column(
              children: [
                Text(_currentDescription,
                    style: const TextStyle(fontSize: 22, height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 15),
                if (widget.storageKey == 'images_transport' ||
                    widget.storageKey == 'images_map') ...[
                  const SizedBox(height: 20),
                  ..._routes.asMap().entries.map((entry) {
                    int idx = entry.key;
                    Map<String, dynamic> item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onLongPress: widget.isAdminMode
                            ? () => _addOrEditRouteDialog(index: idx)
                            : null,
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _launchMapAction(item),
                                icon: Icon(
                                    widget.storageKey == 'images_transport'
                                        ? Icons.directions_bus
                                        : Icons.map_outlined,
                                    size: 28),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      widget.storageKey == 'images_transport'
                                          ? Colors.green
                                          : Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                ),
                                label: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(item['name'] ?? '지도 보기',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                        widget.storageKey == 'images_transport'
                                            ? '${item['sName']} → ${item['dName']}'
                                            : item['location'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ),
                            if (widget.isAdminMode)
                              IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteRoute(idx)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  if (widget.isAdminMode)
                    TextButton.icon(
                        onPressed: () => _addOrEditRouteDialog(),
                        icon: const Icon(Icons.add_circle),
                        label: const Text('새 항목 추가',
                            style: TextStyle(fontSize: 18))),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _imagePaths.isEmpty
                    ? const Center(child: Text('사진이 없습니다.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _imagePaths.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onLongPress: widget.isAdminMode
                                ? () => _deleteImage(index)
                                : null,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 25),
                              child: Image.file(File(_imagePaths[index]),
                                  fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
