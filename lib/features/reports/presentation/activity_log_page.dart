import 'package:flutter/material.dart';
import 'package:hore_app/features/reports/data/report_repository.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/error_handler.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  final ReportRepository _repository = ReportRepository();

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Filter tanggal & pagination
  DateTime _selectedDate = DateTime.now();
  int _currentPage = 0;
  final int _pageSize = 10;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchLogs();
    });
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final fetchedLogs = await _repository.getActivityLogs(
        date: _selectedDate,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _logs = fetchedLogs;
          _hasMoreData = fetchedLogs.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e))));
      }
    }
  }

  // Buat munculkan kalender
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026),
      lastDate: DateTime.now(),
      helpText: "Pilih Tanggal Log",
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _currentPage = 0;
      });
      _fetchLogs();
    }
  }

  // Local Search
  List<Map<String, dynamic>> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    return _logs.where((log) {
      final name = log['employee_name'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Aktivitas Pegawai"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
            tooltip: "Pilih Tanggal",
          ),
          IconButton(
            onPressed: _fetchLogs,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Data Tanggal: $formattedDate",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: "Cari nama pegawai...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Daftar Log
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? Center(child: Text("Tidak ada aktivitas pada tanggal $formattedDate."))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical, // Scroll ke bawah untuk sisa baris
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal, // Scroll ke samping jika layar HP sempit
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.blue.shade100),
                                  dataRowMinHeight: 50,
                                  dataRowMaxHeight: 70, // Memberikan ruang untuk 2 baris teks (WiFi & Lat/Lng)
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Waktu', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Nama Pegawai', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Jaringan & Lokasi', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _filteredLogs.asMap().entries.map((entry) {
                                    final int index = entry.key;
                                    final Map<String, dynamic> log = entry.value;

                                    final DateTime time = DateTime.parse(log['created_at']).toLocal();
                                    final String formattedTime = DateFormat('HH:mm:ss').format(time);
                                    final bool isMock = log['is_mock_locator'] == true;
                                    final String wifi = log['activity_wifi']?.toString().isNotEmpty == true ? log['activity_wifi'] : '-';
                                    final String latLng = "${log['activity_latitude']}, ${log['activity_longitude']}";

                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                                        return index.isOdd ? Colors.blue.shade50 : Colors.white;
                                      }),
                                      cells: [
                                        // 1. Kolom Waktu
                                        DataCell(Text(formattedTime)),
                                        
                                        // 2. Kolom Nama Pegawai
                                        DataCell(Text(log['employee_name'], style: const TextStyle(fontWeight: FontWeight.w500))),
                                        
                                        // 3. Kolom Lokasi (Dibuat 2 baris agar rapi)
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("WiFi: $wifi", style: const TextStyle(fontSize: 13)),
                                              Text(latLng, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        
                                        // 4. Kolom Status (Badge Aman / Fake GPS)
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isMock ? Colors.red.shade100 : Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isMock ? 'Fake GPS' : 'Aman',
                                              style: TextStyle(
                                                color: isMock ? Colors.red.shade800 : Colors.green.shade800,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Kontrol pagination
          if (!_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade300, blurRadius: 4, offset: const Offset(0, -2))
                ]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Tombol Sebelumnya
                  ElevatedButton.icon(
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() => _currentPage--);
                            _fetchLogs();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text("Prev"),
                  ),
                  
                  // Info Halaman Aktif
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Halaman ${_currentPage + 1}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  
                  // Tombol Selanjutnya
                  ElevatedButton.icon(
                    onPressed: _hasMoreData
                        ? () {
                            setState(() => _currentPage++);
                            _fetchLogs();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text("Next"),
                    style: ElevatedButton.styleFrom(iconAlignment: IconAlignment.end),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}