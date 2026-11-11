import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../karyawan/models/kantor_setting.dart';
import '../models/hari_libur_model.dart';
import '../providers/admin_pengaturan_provider.dart';

class PengaturanKantorScreen extends ConsumerStatefulWidget {
  const PengaturanKantorScreen({super.key});

  @override
  ConsumerState<PengaturanKantorScreen> createState() =>
      _PengaturanKantorScreenState();
}

class _PengaturanKantorScreenState
    extends ConsumerState<PengaturanKantorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Pengaturan Kantor & Libur',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: const Color(0xFF737686),
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded), text: 'Lokasi & Jadwal'),
            Tab(icon: Icon(Icons.event_available_rounded), text: 'Hari Libur'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TabLokasiJadwal(),
          _TabHariLibur(),
        ],
      ),
    );
  }
}

class _TabLokasiJadwal extends ConsumerStatefulWidget {
  const _TabLokasiJadwal();

  @override
  ConsumerState<_TabLokasiJadwal> createState() => _TabLokasiJadwalState();
}

class _TabLokasiJadwalState extends ConsumerState<_TabLokasiJadwal> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();
  final _jamMasukController = TextEditingController();
  final _jamPulangController = TextEditingController();
  final _toleransiController = TextEditingController();

  List<int> _hariKerja = [1, 2, 3, 4, 5];
  bool _isInit = false;
  bool _isSaving = false;
  dynamic _settingId;

  final Map<int, String> _namaHari = {
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
    7: 'Minggu',
  };

  void _populateData(KantorSetting setting) {
    if (_isInit) return;
    _settingId = setting.id;
    _namaController.text = setting.nama;
    _latController.text = setting.latitude.toString();
    _lngController.text = setting.longitude.toString();
    _radiusController.text = setting.radiusMeter.toStringAsFixed(0);
    _jamMasukController.text = setting.jamMasuk.substring(0, 5);
    _jamPulangController.text = setting.jamPulang.substring(0, 5);
    _toleransiController.text = setting.toleransiMenit.toString();
    _hariKerja = List<int>.from(setting.hariKerja);
    _isInit = true;
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latController.text = pos.latitude.toString();
        _lngController.text = pos.longitude.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat berhasil diisi dari GPS perangkat saat ini.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membaca GPS: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pilihJam(TextEditingController controller) async {
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    try {
      final parts = controller.text.split(':');
      if (parts.length >= 2) {
        initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => controller.text = formatted);
    }
  }

  Future<void> _saveSetting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(adminPengaturanServiceProvider);
      await service.updateKantorSetting(
        id: _settingId,
        nama: _namaController.text,
        latitude: double.parse(_latController.text),
        longitude: double.parse(_lngController.text),
        radiusMeter: double.parse(_radiusController.text),
        jamMasuk: '${_jamMasukController.text}:00',
        jamPulang: '${_jamPulangController.text}:00',
        toleransiMenit: int.parse(_toleransiController.text),
        hariKerja: _hariKerja,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan kantor berhasil disimpan.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingAsync = ref.watch(adminKantorSettingProvider);

    return settingAsync.when(
      data: (setting) {
        if (setting != null) {
          _populateData(setting);
        }

        return ResponsiveCenter(
          maxWidth: 600,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Lokasi GPS & Radius
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E7FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Titik Koordinat & Radius Kantor',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _namaController,
                          decoration: const InputDecoration(labelText: 'Nama Kantor / Cabang'),
                          validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Latitude'),
                                validator: (v) => v == null || double.tryParse(v) == null ? 'Wajib desimal' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _lngController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Longitude'),
                                validator: (v) => v == null || double.tryParse(v) == null ? 'Wajib desimal' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: const Text('Ambil Koordinat dari Lokasi Saya Saat Ini'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _radiusController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Radius Presensi (Meter)',
                            suffixText: 'meter',
                          ),
                          validator: (v) => v == null || int.tryParse(v) == null ? 'Wajib angka' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card Jam Kerja & Toleransi
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E7FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.schedule_rounded, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Jadwal Jam Kerja & Toleransi',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _jamMasukController,
                                readOnly: true,
                                onTap: () => _pilihJam(_jamMasukController),
                                decoration: const InputDecoration(
                                  labelText: 'Jam Masuk',
                                  suffixIcon: Icon(Icons.access_time_rounded),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _jamPulangController,
                                readOnly: true,
                                onTap: () => _pilihJam(_jamPulangController),
                                decoration: const InputDecoration(
                                  labelText: 'Jam Pulang',
                                  suffixIcon: Icon(Icons.access_time_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _toleransiController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Toleransi Keterlambatan (Menit)',
                            hintText: 'Mis. 15',
                            suffixText: 'menit',
                          ),
                          validator: (v) => v == null || int.tryParse(v) == null ? 'Wajib angka' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card Hari Kerja
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E7FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.date_range_rounded, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Hari Kerja Aktif',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pilih hari yang diwajibkan untuk presensi karyawan.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF737686)),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _namaHari.entries.map((entry) {
                            final isChecked = _hariKerja.contains(entry.key);
                            return FilterChip(
                              label: Text(entry.value),
                              selected: isChecked,
                              selectedColor: AppTheme.primaryBlue,
                              labelStyle: TextStyle(
                                color: isChecked ? Colors.white : const Color(0xFF434655),
                                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _hariKerja.add(entry.key);
                                    _hariKerja.sort();
                                  } else {
                                    if (_hariKerja.length > 1) {
                                      _hariKerja.remove(entry.key);
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Simpan
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveSetting,
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Simpan Pengaturan Kantor'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      error: (err, _) => Center(child: Text('Gagal memuat pengaturan: $err')),
    );
  }
}

class _TabHariLibur extends ConsumerWidget {
  const _TabHariLibur();

  void _showAddLiburDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => const _AddHariLiburDialog(),
    );
  }

  void _confirmDeleteLibur(BuildContext context, WidgetRef ref, HariLiburModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Hari Libur'),
        content: Text('Hapus hari libur ${item.tanggal} (${item.keterangan})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final service = ref.read(adminPengaturanServiceProvider);
        await service.deleteHariLibur(item.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hari libur berhasil dihapus')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hariLiburAsync = ref.watch(adminHariLiburListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLiburDialog(context, ref),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Hari Libur'),
      ),
      body: ResponsiveCenter(
        maxWidth: 600,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: hariLiburAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E7FF)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_note_rounded, size: 48, color: Color(0xFF737686)),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada hari libur yang didaftarkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF737686), fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (ctx, index) {
                final item = list[index];
                DateTime? dt;
                try {
                  dt = DateTime.parse(item.tanggal);
                } catch (_) {}

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E7FF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.beach_access_rounded, color: Colors.red.shade600, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dt != null ? formatTanggalLengkap(dt) : item.tanggal,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.keterangan,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF737686)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _confirmDeleteLibur(context, ref, item),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
          error: (err, _) => Center(child: Text('Gagal memuat: $err')),
        ),
      ),
    );
  }
}

class _AddHariLiburDialog extends ConsumerStatefulWidget {
  const _AddHariLiburDialog();

  @override
  ConsumerState<_AddHariLiburDialog> createState() => _AddHariLiburDialogState();
}

class _AddHariLiburDialogState extends ConsumerState<_AddHariLiburDialog> {
  final _keteranganController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (_keteranganController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keterangan hari libur wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(adminPengaturanServiceProvider);
      final strTanggal = formatTanggalDb(_selectedDate);

      await service.addHariLibur(
        tanggal: strTanggal,
        keterangan: _keteranganController.text,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hari libur berhasil ditambahkan.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Tambah Hari Libur'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _pilihTanggal,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatTanggalLengkap(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryBlue, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _keteranganController,
              decoration: const InputDecoration(
                labelText: 'Keterangan Hari Libur',
                hintText: 'Mis. Hari Raya Nyepi',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
