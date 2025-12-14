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
        title: const Text('효자 지도맵', style: TextStyle(fontSize: 28)),
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

            // 2번 폴더: 버스 경로 + 집 to 전철역 (경로 찾기 - 출발지/목적지 모두 입력)
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

            // 3번 폴더: 현재위치에서 목적지 가는 길 (출발지 = 현재위치 고정)
            Expanded(
              child: _buildBigFolderCard(
                context,
                title: '현재위치에서 목적지 가는 길', // 제목 변경
                icon: Icons.navigation, // 아이콘 변경
                color: Colors.green.shade100, // 색상 변경
                iconColor: Colors.green.shade800,
                page: DetailGalleryPage(
                  storageKey: 'images_hospital', // 기존 키 유지를 위해 사용
                  title: '현재위치에서 목적지 가는 길', // 제목 변경
                  description: '지금 계신 곳에서\n목적지까지 가는 방법입니다.', // 설명 변경
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
                fontSize: 26,
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
// 믹스인 및 유틸리티 클래스 (수정된 버전)
// ----------------------------------------------------

mixin AdminDialogsMixin<T extends StatefulWidget> on State<T> {
  // Mixin에서 필요한 상태 변수 정의 (DetailGalleryPage에서 정의됨)
  abstract String _currentDescription;
  abstract List<Map<String, dynamic>> _routes;

  // Mixin에서 필요한 메서드 정의 (DetailGalleryPage에서 정의됨)
  Future<void> _saveDescription(String newDescription);
  Future<void> _saveRoutes();

  // [1] 장소/경로 추가 또는 수정 다이얼로그
  Future<void> _addOrEditRouteDialog({int? index}) async {
    final state = this as _DetailGalleryPageState; // 캐스팅

    // 모드 확인
    bool isCurrentToDest =
        state.widget.storageKey == 'images_hospital'; // 현재위치->목적지 모드
    bool isTransport =
        state.widget.storageKey == 'images_transport'; // 버스/전철 모드
    bool isRouteMode = isCurrentToDest || isTransport;

    Map<String, dynamic> initialData = index != null
        ? _routes[index]
        : (isRouteMode
            ? {'name': '', 'sName': '', 'dName': ''}
            : {'name': '', 'location': ''});

    final nameController = TextEditingController(text: initialData['name']);
    final sNameController = TextEditingController(text: initialData['sName']);
    final dNameController = TextEditingController(text: initialData['dName']);
    final locationController =
        TextEditingController(text: initialData['location']);

    await showDialog(
      context: state.context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? '새 항목 추가' : '항목 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: '버튼 이름 (예: 복지관 가는 길)')),
                const SizedBox(height: 10),

                // 경로 모드일 때
                if (isRouteMode) ...[
                  // 버스/전철일 때만 출발지 입력을 받습니다.
                  if (isTransport)
                    TextField(
                        controller: sNameController,
                        decoration: const InputDecoration(
                            labelText: '출발지 주소 (예: 우리집)')),

                  TextField(
                      controller: dNameController,
                      decoration: const InputDecoration(
                          labelText: '도착지 주소 (예: 시청, 서울역)')),

                  // 현재위치->목적지 모드일 때 안내 문구
                  if (isCurrentToDest)
                    const Padding(
                      padding: EdgeInsets.only(top: 15.0),
                      child: Text("※ '현재 위치'에서 출발하는 경로입니다.\n도착지만 입력하면 됩니다.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                ] else ...[
                  // 일반 장소 검색 모드 (집 주변 지도)
                  TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                          labelText: '장소 주소 (예: 동네마트 주소)')),
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
                  state.setState(() {
                    Map<String, dynamic> data;

                    if (isRouteMode) {
                      data = {
                        'name': nameController.text,
                        // 현재위치 모드이면 출발지('')로 비워서 저장
                        'sName': isCurrentToDest ? '' : sNameController.text,
                        'dName': dNameController.text
                      };
                    } else {
                      data = {
                        'name': nameController.text,
                        'location': locationController.text
                      };
                    }

                    if (index == null) {
                      _routes.add(data);
                    } else {
                      _routes[index] = data;
                    }
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

  // [2] 설명 수정 다이얼로그
  Future<void> _editDescriptionDialog() async {
    final state = this as _DetailGalleryPageState;
    final TextEditingController controller =
        TextEditingController(text: _currentDescription);
    await showDialog(
      context: state.context,
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

  // [3] 지도 우선순위 설정 (즉시 드래그 적용됨)
  Future<void> _showPrioritySettingsDialog() async {
    final state = this as _DetailGalleryPageState;
    final prefs = await SharedPreferences.getInstance();

    List<String> currentOrder =
        prefs.getStringList('map_priority') ?? MapActionUtils.defaultPriority;
    List<String> tempOrder = List.from(currentOrder);

    Map<String, String> mapNames = {
      MapActionUtils.TYPE_NAVER: '네이버 지도',
      MapActionUtils.TYPE_KAKAO: '카카오맵',
      MapActionUtils.TYPE_TMAP: '티맵 (TMAP)',
      MapActionUtils.TYPE_GOOGLE: '구글 지도',
      MapActionUtils.TYPE_WEB: '인터넷(웹) 브라우저',
    };

    Map<String, IconData> mapIcons = {
      MapActionUtils.TYPE_NAVER: Icons.map,
      MapActionUtils.TYPE_KAKAO: Icons.near_me,
      MapActionUtils.TYPE_TMAP: Icons.navigation,
      MapActionUtils.TYPE_GOOGLE: Icons.public,
      MapActionUtils.TYPE_WEB: Icons.web,
    };

    if (!state.mounted) return;

    await showDialog(
      context: state.context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('지도 실행 순위 설정'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: [
                    const Text('위쪽일수록 먼저 실행됩니다.\n(오른쪽 손잡이를 잡고 순서를 바꾸세요)',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ReorderableListView(
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) {
                          setDialogState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final String item = tempOrder.removeAt(oldIndex);
                            tempOrder.insert(newIndex, item);
                          });
                        },
                        children: [
                          for (int i = 0; i < tempOrder.length; i++)
                            ListTile(
                              key: ValueKey(tempOrder[i]),
                              leading: Text('${i + 1}순위',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal)),
                              title: Row(
                                children: [
                                  Icon(mapIcons[tempOrder[i]],
                                      size: 20, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Text(mapNames[tempOrder[i]] ?? tempOrder[i]),
                                ],
                              ),
                              trailing: ReorderableDragStartListener(
                                index: i,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  color: Colors.transparent,
                                  child: const Icon(Icons.drag_handle,
                                      color: Colors.grey),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await prefs.setStringList('map_priority', tempOrder);
                    if (state.mounted) {
                      ScaffoldMessenger.of(state.context).showSnackBar(
                        const SnackBar(content: Text('실행 순위가 저장되었습니다.')),
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

mixin DataManagementMixin<T extends StatefulWidget> on State<T> {
  // DetailGalleryPage의 상태와 연결되어야 하는 변수들
  abstract List<String> _imagePaths;
  abstract String _currentDescription;
  abstract List<Map<String, dynamic>> _routes;
  abstract bool _isLoading;
  final ImagePicker _picker = ImagePicker();

  // DetailGalleryPage의 위젯 프로퍼티 접근을 위한 추상 getter
  String get storageKey;
  String get description;

  // 데이터 로드
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _imagePaths = prefs.getStringList(storageKey) ?? [];
      _currentDescription =
          prefs.getString('${storageKey}_desc') ?? description;

      String? routesJson = prefs.getString('${storageKey}_routes');
      if (routesJson != null) {
        _routes = List<Map<String, dynamic>>.from(jsonDecode(routesJson));
      }
      _isLoading = false;
    });
  }

  // 이미지 경로 저장
  Future<void> _saveImages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(storageKey, _imagePaths);
  }

  // 설명 저장
  Future<void> _saveDescription(String newDescription) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${storageKey}_desc', newDescription);
    setState(() {
      _currentDescription = newDescription;
    });
  }

  // 경로 저장
  Future<void> _saveRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${storageKey}_routes', jsonEncode(_routes));
  }

  // 이미지 추가
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
    } catch (e) {
      // 오류 처리
    }
  }

  // 이미지 삭제
  Future<void> _deleteImage(int index) async {
    setState(() {
      _imagePaths.removeAt(index);
    });
    await _saveImages();
  }

  // 경로/장소 삭제
  Future<void> _deleteRoute(int index) async {
    setState(() {
      _routes.removeAt(index);
    });
    _saveRoutes();
  }
}

class MapActionUtils {
  final BuildContext context;
  final String storageKey;

  MapActionUtils(this.context, this.storageKey);

  // 지도 타입 정의
  static const String TYPE_NAVER = 'naver';
  static const String TYPE_KAKAO = 'kakao';
  static const String TYPE_TMAP = 'tmap';
  static const String TYPE_GOOGLE = 'google';
  static const String TYPE_WEB = 'web';

  // 기본 우선순위
  static const List<String> defaultPriority = [
    TYPE_NAVER,
    TYPE_KAKAO,
    TYPE_TMAP,
    TYPE_GOOGLE,
    TYPE_WEB
  ];

  Future<void> _launchUrlSafe(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Launch Error: $e');
    }
  }

  // URL 생성 도우미 (타입별 URL 반환)
  Uri? _generateUrl(
      String type,
      bool isRouteMode,
      String? sName,
      double? sLat,
      double? sLng,
      String? dName,
      double? dLat,
      double? dLng,
      String? location) {
    // 데이터 정리
    String destName = isRouteMode ? (dName ?? '') : (location ?? '');

    // [수정됨] 모드 설정: 모든 경로 모드(교통, 현재위치->목적지)는 '대중교통'으로 설정합니다.
    String naverRouteMode = 'public';
    String kakaoRouteMode = 'PUBLICTRANSIT';
    String googleTravelMode = 'transit';
    String webRouteMode = 'transit';

    // 출발지 이름이 비어있으면(현재위치->목적지 모드) 현재 위치로 간주하므로, 좌표는 null 처리
    double? startLat = (sName ?? '').isEmpty ? null : sLat;
    double? startLng = (sName ?? '').isEmpty ? null : sLng;

    switch (type) {
      case TYPE_NAVER:
        if (isRouteMode) {
          String params =
              'nmap://route/$naverRouteMode?appname=com.example.grandparents_map';
          if (startLat != null && startLng != null) {
            params +=
                '&slat=$startLat&slng=$startLng&sname=${Uri.encodeComponent(sName ?? '')}';
          }
          if (dLat != null && dLng != null) {
            params +=
                '&dlat=$dLat&dlng=$dLng&dname=${Uri.encodeComponent(dName ?? '')}';
          } else {
            params += '&dname=${Uri.encodeComponent(dName ?? '')}';
          }
          return Uri.parse(params);
        } else {
          return Uri.parse(
              'nmap://search?query=${Uri.encodeComponent(location ?? '')}&appname=com.example.grandparents_map');
        }

      case TYPE_KAKAO:
        if (isRouteMode) {
          if (dLat != null && dLng != null) {
            String spParam = (startLat != null && startLng != null)
                ? 'sp=$startLat,$startLng&'
                : '';
            return Uri.parse(
                'kakaomap://route?${spParam}ep=$dLat,$dLng&by=$kakaoRouteMode');
          } else {
            return Uri.parse(
                'kakaomap://search?q=${Uri.encodeComponent(dName ?? '')}');
          }
        } else {
          return Uri.parse(
              'kakaomap://search?q=${Uri.encodeComponent(location ?? '')}');
        }

      case TYPE_TMAP:
        return Uri.parse('tmap://search?name=${Uri.encodeComponent(destName)}');

      case TYPE_GOOGLE:
        if (isRouteMode && dLat != null && dLng != null) {
          String url =
              'https://www.google.com/maps/dir/?api=1&destination=$dLat,$dLng&travelmode=$googleTravelMode';
          if (startLat != null && startLng != null) {
            url += '&origin=$startLat,$startLng';
          }
          return Uri.parse(url);
        } else {
          return Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(destName)}');
        }

      case TYPE_WEB:
        // 웹 URL 생성
        if (isRouteMode) {
          if (startLat != null &&
              startLng != null &&
              dLat != null &&
              dLng != null) {
            return Uri.parse(
                'https://map.naver.com/p/directions/$startLng,$startLat,${Uri.encodeComponent(sName ?? '')}/$dLng,$dLat,${Uri.encodeComponent(dName ?? '')}/$webRouteMode');
          } else {
            // 출발지 좌표가 없으면(현재위치->목적지 모드 등) -> 출발지는 비워두고(현재위치) 도착지만 설정
            return Uri.parse(
                'https://map.naver.com/p/directions/-/-/-/$webRouteMode?goalPlace=${Uri.encodeComponent(dName ?? '')}');
          }
        } else {
          return Uri.parse(
              'https://map.naver.com/p/search/${Uri.encodeComponent(location ?? '')}');
        }

      default:
        return null;
    }
  }

  // 메인 실행 함수
  Future<void> launchMapAction(Map<String, dynamic> item) async {
    // 1. 로딩 표시
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
      if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
    }

    // 2. 우선순위 불러오기
    final prefs = await SharedPreferences.getInstance();
    List<String> priorityList =
        prefs.getStringList('map_priority') ?? defaultPriority;

    bool isRouteMode =
        storageKey == 'images_transport' || storageKey == 'images_hospital';

    try {
      String sName = (item['sName'] ?? '').trim();
      String dName = (item['dName'] ?? '').trim();
      String location = (item['location'] ?? '').trim();

      // 좌표 변환 (Geocoding)
      double? sLat, sLng, dLat, dLng;

      if (isRouteMode) {
        // 출발지 이름(sName)이 있으면 좌표 변환 시도
        if (sName.isNotEmpty) {
          try {
            List<Location> sLocs = await locationFromAddress(sName);
            if (sLocs.isNotEmpty) {
              sLat = sLocs.first.latitude;
              sLng = sLocs.first.longitude;
            }
          } catch (e) {/*무시*/}
        }
        // 도착지 이름(dName)이 있으면 좌표 변환 시도
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

      closeLoading(); // 로딩 종료

      // 3. 우선순위 순서대로 실행 시도
      bool launched = false;

      for (String mapType in priorityList) {
        Uri? url = _generateUrl(mapType, isRouteMode, sName, sLat, sLng, dName,
            dLat, dLng, location);

        if (url == null) continue;

        if (mapType == TYPE_WEB) {
          // 웹은 설치 여부 상관없이 무조건 실행
          await _launchUrlSafe(url);
          launched = true;
          break;
        } else {
          // 앱은 설치되어 있는지 확인
          if (await canLaunchUrl(url)) {
            await _launchUrlSafe(url);
            launched = true;
            break;
          }
        }
      }

      // 4. 모든 앱이 없으면 웹으로 폴백
      if (!launched) {
        Uri? webUrl = _generateUrl(TYPE_WEB, isRouteMode, sName, sLat, sLng,
            dName, dLat, dLng, location);
        if (webUrl != null) await _launchUrlSafe(webUrl);
      }
    } catch (e) {
      closeLoading();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('주소를 찾을 수 없습니다.')));
      }
    }
  }
}

// ----------------------------------------------------
// 상세 페이지 (DetailGalleryPage)
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

// DataManagementMixin, AdminDialogsMixin 사용
class _DetailGalleryPageState extends State<DetailGalleryPage>
    with DataManagementMixin, AdminDialogsMixin {
  // DataManagementMixin에서 필요한 추상 getter 구현
  @override
  String get storageKey => widget.storageKey;
  @override
  String get description => widget.description;

  // Mixin에서 필요한 상태 변수 정의
  @override
  List<String> _imagePaths = [];
  @override
  String _currentDescription = "";
  @override
  List<Map<String, dynamic>> _routes = [];
  @override
  bool _isLoading = true;

  // Mixin 호환성을 위해 남겨두지만, 실제 로직에서는 사용하지 않음
  @override
  bool _useWebMapOnly = false;
  @override
  bool _suppressWebConfirm = false;

  late MapActionUtils _mapActionUtils;

  @override
  void initState() {
    super.initState();
    _currentDescription = widget.description;
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapActionUtils = MapActionUtils(context, widget.storageKey);
  }

  @override
  void didUpdateWidget(covariant DetailGalleryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey) {
      _mapActionUtils = MapActionUtils(context, widget.storageKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3번 폴더: 현재위치에서 목적지 (구 병원)
    bool isCurrentToDest = widget.storageKey == 'images_hospital';
    bool isTransport = widget.storageKey == 'images_transport';
    bool isRouteMode = isTransport || isCurrentToDest;

    // 아이콘과 색상 설정
    IconData mapButtonIcon = isCurrentToDest
        ? Icons.navigation // 길찾기 아이콘
        : (isTransport ? Icons.directions_bus : Icons.map_outlined);

    Color mapButtonColor = isCurrentToDest
        ? Colors.green.shade700 // 초록색 (안전한 느낌)
        : (isTransport ? Colors.blue.shade700 : Colors.deepOrange); // 파란색, 주황색

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 26)),
        toolbarHeight: 70,
        actions: [
          if (widget.isAdminMode) ...[
            // 설명 수정 버튼
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
          // 관리자 모드일 때: 지도 실행 우선순위 설정 UI 표시
          if (widget.isAdminMode)
            Container(
              color: Colors.blueGrey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, color: Colors.deepPurple),
                      SizedBox(width: 10),
                      Text('지도 앱 실행 설정',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showPrioritySettingsDialog,
                    icon: const Icon(Icons.sort),
                    label: const Text('순위 변경'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      elevation: 1,
                    ),
                  ),
                ],
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
                if (isRouteMode || widget.storageKey == 'images_map') ...[
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
                                onPressed: () =>
                                    _mapActionUtils.launchMapAction(item),
                                icon: Icon(mapButtonIcon, size: 28),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mapButtonColor,
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

                                    // 텍스트 표시 로직
                                    Builder(builder: (context) {
                                      // 1. 일반 장소 검색 모드
                                      if (!isRouteMode) {
                                        return Text(item['location'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.white70),
                                            overflow: TextOverflow.ellipsis);
                                      }

                                      // 2. 현재위치에서 목적지 모드 (출발지 표시 고정)
                                      if (isCurrentToDest) {
                                        return Text('현재 위치 → ${item['dName']}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.white70),
                                            overflow: TextOverflow.ellipsis);
                                      }

                                      // 3. 버스/전철 모드 (출발지 -> 목적지)
                                      String sName = item['sName'] ?? '';
                                      String dName = item['dName'] ?? '';
                                      String label = sName.isNotEmpty
                                          ? '$sName → $dName'
                                          : '출발지 미정 → $dName';

                                      return Text(label,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70),
                                          overflow: TextOverflow.ellipsis);
                                    }),
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
