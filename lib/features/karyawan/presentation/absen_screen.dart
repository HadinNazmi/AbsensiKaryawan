import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/absensi_model.dart';
import '../models/kantor_setting.dart';
import '../providers/absensi_provider.dart';

enum LocationState {
  checking,
  ready,
  serviceDisabled,
  permissionDenied,
}

enum CameraState {
  initial,
  ready,
  permissionDenied,
  error,
}

class AbsenScreen extends ConsumerStatefulWidget {
  final String tipe; // 'masuk' atau 'pulang'

  const AbsenScreen({super.key, required this.tipe});

  @override
  ConsumerState<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends ConsumerState<AbsenScreen> {
  // Lokasi & GPS
  LocationState _locationState = LocationState.checking;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  double _distanceToOffice = 0;
  bool _isInRadius = false;
  bool _isAccuracyOk = false;
  String? _locationErrorMessage;

  // Kamera
  CameraController? _cameraController;
  CameraState _cameraState = CameraState.initial;
  String? _cameraErrorMessage;
  Uint8List? _capturedPhotoBytes;

  // Status Pengiriman
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    // Matikan stream GPS dan Kamera saat meninggalkan halaman
    _positionSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  /// Inisialisasi Lokasi dan Izin GPS
  Future<void> _initLocation() async {
    setState(() {
      _locationState = LocationState.checking;
      _locationErrorMessage = null;
    });

    try {
      // 1. Cek layanan GPS aktif
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationState = LocationState.serviceDisabled;
        });
        return;
      }

      // 2. Cek izin lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationState = LocationState.permissionDenied;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationState = LocationState.permissionDenied;
        });
        return;
      }

      // 3. Ambil posisi saat ini
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _updatePosition(pos);
      setState(() {
        _locationState = LocationState.ready;
      });

      // 4. Buka stream posisi untuk update berkala
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1, // update setiap 1 meter
        ),
      ).listen(
        _updatePosition,
        onError: (err) {
          setState(() {
            _locationErrorMessage = 'Kendala GPS: ${err.toString()}';
          });
        },
      );

      // 5. Inisialisasi kamera depan
      _initCamera();
    } catch (e) {
      setState(() {
        _locationErrorMessage = 'Gagal mengakses lokasi: $e';
        _locationState = LocationState.permissionDenied;
      });
    }
  }

  /// Update koordinat, hitung jarak ke kantor dan validasi radius
  void _updatePosition(Position pos) {
    final kantorSetting = ref.read(kantorSettingProvider).value;
    if (kantorSetting == null) return;

    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      kantorSetting.latitude,
      kantorSetting.longitude,
    );

    final inRadius = distance <= kantorSetting.radiusMeter;
    final accuracyOk = pos.accuracy <= 100; // Akurasi GPS harus <= 100m

    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _distanceToOffice = distance;
        _isInRadius = inRadius;
        _isAccuracyOk = accuracyOk;
      });
    }
  }

  /// Inisialisasi kamera depan
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraState = CameraState.error;
          _cameraErrorMessage = 'Tidak ada perangkat kamera ditemukan.';
        });
        return;
      }

      // Prioritaskan kamera depan (front) untuk selfie presensi
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _cameraState = CameraState.ready;
        });
      }
    } on CameraException {
      if (mounted) {
        setState(() {
          _cameraState = CameraState.permissionDenied;
          _cameraErrorMessage =
              'Izin kamera ditolak. Silakan izinkan akses kamera di peramban (browser).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraState = CameraState.error;
          _cameraErrorMessage = 'Gagal membuka kamera: $e';
        });
      }
    }
  }

  /// Ambil foto selfie langsung dari kamera (tanpa opsi galeri)
  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final xfile = await _cameraController!.takePicture();
      final bytes = await xfile.readAsBytes();

      if (mounted) {
        setState(() {
          _capturedPhotoBytes = bytes;
        });
      }
    } catch (e) {
      _showSnackbar('Gagal mengambil foto: $e', isError: true);
    }
  }

  /// Foto ulang
  void _retakePhoto() {
    setState(() {
      _capturedPhotoBytes = null;
    });
  }

  /// Kirim data presensi ke Supabase RPC submit_absensi
  Future<void> _submitAbsen() async {
    if (_capturedPhotoBytes == null || _currentPosition == null) return;

    final user = ref.read(authNotifierProvider).user;
    if (user == null) {
      _showSnackbar('Sesi telah berakhir, silakan login ulang', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final absensiService = ref.read(absensiServiceProvider);
      final result = await absensiService.submitAbsensi(
        uid: user.id,
        tipe: widget.tipe,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        akurasi: _currentPosition!.accuracy,
        photoBytes: _capturedPhotoBytes!,
      );

      if (!mounted) return;

      // Tampilkan dialog konfirmasi sukses
      await _showSuccessDialog(result);

      if (!mounted) return;
      context.pop(true); // Kembali ke Beranda dengan sinyal refresh
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString().replaceAll('Exception: ', '');
      final isNetworkError = rawMessage.toLowerCase().contains('socket') ||
          rawMessage.toLowerCase().contains('clientexception') ||
          rawMessage.toLowerCase().contains('network') ||
          rawMessage.toLowerCase().contains('failed host lookup');

      final displayMessage =
          isNetworkError ? 'Tidak ada koneksi internet' : rawMessage;

      _showSnackbar(displayMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showSuccessDialog(AbsensiModel absensi) async {
    final jamWib = widget.tipe == 'masuk'
        ? absensi.jamMasukFormatted
        : absensi.jamPulangFormatted;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 40,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Absen ${widget.tipe == 'masuk' ? 'Masuk' : 'Pulang'} Berhasil!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF131B2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Presensi tercatat resmi pada server:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    jamWib ?? '-',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: absensi.statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Status: ${absensi.statusDisplay}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: absensi.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kembali ke Beranda'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kantorAsync = ref.watch(kantorSettingProvider);
    final tipeTitle = widget.tipe == 'masuk' ? 'Presensi Masuk' : 'Presensi Pulang';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          tipeTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: kantorAsync.when(
            data: (kantor) {
              if (kantor == null) {
                return const Center(
                  child: Text('Pengaturan kantor belum dikonfigurasi.'),
                );
              }
              return _buildContent(kantor);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
            error: (err, _) => Center(
              child: Text('Gagal memuat pengaturan kantor: $err'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(KantorSetting kantor) {
    // 1. Jika GPS atau Izin lokasi bermasalah
    if (_locationState == LocationState.serviceDisabled) {
      return _buildGpsDisabledGuide();
    }
    if (_locationState == LocationState.permissionDenied) {
      return _buildLocationPermissionGuide();
    }

    final bool canTakePhoto = _isInRadius && _isAccuracyOk;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A. Geofence & Jarak Radar Card
          _buildRadarStatusCard(kantor),
          const SizedBox(height: 16),

          // B. Area Kamera / Pratinjau Foto
          _buildCameraOrPreviewSection(canTakePhoto),
          const SizedBox(height: 20),

          // C. Tombol Aksi Pengiriman / Ambil Foto
          _buildActionButtons(canTakePhoto),
        ],
      ),
    );
  }

  Widget _buildRadarStatusCard(KantorSetting kantor) {
    final distanceText = '${_distanceToOffice.toStringAsFixed(0)} meter';
    final accuracyText = _currentPosition != null
        ? '±${_currentPosition!.accuracy.toStringAsFixed(0)}m'
        : 'Mencari...';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isInRadius
            ? const Color(0xFFF0FDF4) // Light green
            : const Color(0xFFFEF2F2), // Light red
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isInRadius
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFFECACA),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isInRadius
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isInRadius ? 'DI DALAM AREA KANTOR' : 'DI LUAR AREA KANTOR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isInRadius
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      size: 13,
                      color: _isAccuracyOk ? Colors.blue.shade700 : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Akurasi $accuracyText',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isAccuracyOk ? Colors.blue.shade700 : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.business_rounded,
                  color: _isInRadius
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distanceText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    Text(
                      'ke ${kantor.nama} (Radius maks. ${kantor.radiusMeter.toStringAsFixed(0)}m)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF737686),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GPS Anda: ${_currentPosition != null ? "${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}" : "Mencari..."}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                    Text(
                      'Kantor: ${kantor.latitude.toStringAsFixed(6)}, ${kantor.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isInRadius) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFFECACA), height: 1),
            const SizedBox(height: 8),
            const Text(
              'Anda harus berada di dalam radius kantor untuk dapat melakukan presensi.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ] else if (!_isAccuracyOk) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFFECACA), height: 1),
            const SizedBox(height: 8),
            const Text(
              'Akurasi GPS rendah (>100m). Mohon tunggu beberapa detik agar sinyal GPS lebih stabil.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraOrPreviewSection(bool canTakePhoto) {
    // Jika foto sudah diambil, tampilkan pratinjau foto
    if (_capturedPhotoBytes != null) {
      return Container(
        height: 380,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E7FF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              _capturedPhotoBytes!,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Color(0xFF16A34A), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Foto Siap Dikirim',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

    // Jika kamera ada kendala izin
    if (_cameraState == CameraState.permissionDenied) {
      return _buildCameraPermissionGuide();
    }

    // Jika kamera belum siap
    if (_cameraState != CameraState.ready || _cameraController == null) {
      return Container(
        height: 380,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryBlue),
              SizedBox(height: 12),
              Text(
                'Menyiapkan kamera selfie...',
                style: TextStyle(fontSize: 13, color: Color(0xFF737686)),
              ),
            ],
          ),
        ),
      );
    }

    // Live Camera Preview
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          // Tag Kamera Langsung
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: Colors.redAccent, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'KAMERA DEPAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bounding Oval Guide untuk Swafoto
          Center(
            child: Container(
              width: 220,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: canTakePhoto
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(140),
              ),
            ),
          ),
          if (!canTakePhoto)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Kamera terkunci: Anda belum berada di dalam radius kantor atau akurasi GPS belum memadai.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool canTakePhoto) {
    // Mode A: Sudah ada foto diambil -> Tampilkan "Kirim Absen" & "Foto Ulang"
    if (_capturedPhotoBytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitAbsen,
            icon: _isSubmitting
                ? const SizedBox.shrink()
                : const Icon(Icons.send_rounded, size: 20),
            label: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Memvalidasi ke Server...'),
                    ],
                  )
                : Text('Kirim Absen ${widget.tipe == 'masuk' ? 'Masuk' : 'Pulang'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.tipe == 'masuk'
                  ? AppTheme.primaryBlue
                  : const Color(0xFFEA580C),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _retakePhoto,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Foto Ulang'),
          ),
        ],
      );
    }

    // Mode B: Belum ambil foto -> Tombol "Ambil Foto" (aktif jika di dalam radius)
    return ElevatedButton.icon(
      onPressed: canTakePhoto ? _takePhoto : null,
      icon: const Icon(Icons.camera_alt_rounded, size: 22),
      label: Text(
        canTakePhoto
            ? 'Ambil Foto Selfie'
            : (_isInRadius ? 'Menunggu Akurasi GPS...' : 'Di Luar Area Kantor'),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  // --- Panduan Akses / Izin ---
  Widget _buildLocationPermissionGuide() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E7FF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.location_off_rounded,
                color: Colors.red.shade600, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Izin Lokasi Diperlukan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF131B2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _locationErrorMessage ??
                'Aplikasi membutuhkan izin GPS untuk memvalidasi bahwa Anda berada di area kantor sebelum absen.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF737686), height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cara Mengaktifkan di Browser:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131B2E),
                  ),
                ),
                SizedBox(height: 6),
                Text('1. Klik ikon gembok / perizinan di bilah alamat browser.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF434655))),
                Text('2. Cari menu "Lokasi" (Location) dan ubah ke "Izinkan" (Allow).',
                    style: TextStyle(fontSize: 12, color: Color(0xFF434655))),
                Text('3. Klik tombol "Coba Lagi" di bawah.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF434655))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initLocation,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsDisabledGuide() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E7FF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.gps_off_rounded,
                color: Colors.amber.shade800, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'GPS / Lokasi Belum Aktif',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF131B2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Silakan aktifkan GPS atau Layanan Lokasi di perangkat / HP Anda, lalu tekan tombol coba lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF737686), height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _initLocation,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPermissionGuide() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E7FF)),
      ),
      child: Column(
        children: [
          const Icon(Icons.no_photography_rounded, color: Colors.red, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Izin Kamera Ditolak',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            _cameraErrorMessage ??
                'Mohon izinkan akses kamera pada peramban (browser) untuk mengambil swafoto presensi.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF737686)),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _initCamera,
            child: const Text('Muat Ulang Kamera'),
          ),
        ],
      ),
    );
  }
}
