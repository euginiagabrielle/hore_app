import 'package:flutter/material.dart';
import '../data/employee_repository.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  final EmployeeRepository _repository = EmployeeRepository();
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _repository.getEmployees();
      setState(() {
        _employees = data;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmation(String title, String content) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false; // if user click outside the dialogue box
  }

  Future<void> _toggleTrusted(String id, bool currentValue) async {
    // show pop-up
    final bool confirm = await _showConfirmation(
      "Ubah Hak Akses?",
      currentValue
          ? "Admin ini akan kehilangan akses manajemen pegawai."
          : "Admin ini akan diberikan kepercayaan penuh.",
    );

    if (!confirm) return;

    // update database
    try {
      await _repository.updateTrustedStatus(id, !currentValue);
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status kepercayaan berhasil diubah!")),
        );
      }
    } catch (e) {
      // If fail, return to previous UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal diperbarui: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleActive(String id, bool currentValue) async {
    // show pop-up
    final bool confirm = await _showConfirmation(
      currentValue ? "Nonaktifkan Pegawai?" : "Aktifkan Pegawai",
      currentValue ? "Pegawai ini dinonaktifkan." : "Pegawai ini diaktifkan.",
    );

    if (!confirm) return;

    try {
      await _repository.updateActiveStatus(id, !currentValue);
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentValue ? "Pegawai dinonaktifkan." : "Pegawai diaktifkan.",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal diperbarui: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manajemen Pegawai")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final employee = _employees[index];

                // get data
                final String name = employee['employee_name'] ?? 'No Name';
                final String role = employee['employee_role'];
                final bool isTargetOwner = role == 'owner';
                final String nip = employee['nip'] ?? '-';
                final bool isTrusted = employee['is_trusted'] ?? false;
                final bool isActive = employee['is_employee_active'] ?? true;
                final String id = employee['auth_user_id'];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: isActive ? null : Colors.grey[200],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isActive
                                  ? (isTrusted ? Colors.blue : Colors.orange)
                                  : Colors.grey,
                              child: Icon(
                                isActive ? Icons.person : Icons.block,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      decoration: isActive
                                          ? null
                                          : TextDecoration.lineThrough,
                                      color: isActive
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "NIP: $nip | Role: ${role.toUpperCase()}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Divider(),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // trusted toggle
                            Row(
                              children: [
                                const Text(
                                  "Trusted Staff: ",
                                  style: TextStyle(fontSize: 12),
                                ),
                                Switch(
                                  value: isTrusted,
                                  activeThumbColor: Colors.blue,
                                  onChanged: (isActive && !isTargetOwner)
                                      ? (val) => _toggleTrusted(id, isTrusted)
                                      : null,
                                ),
                              ],
                            ),

                            // active toggle
                            TextButton.icon(
                              onPressed: (isTargetOwner)
                                  ? null
                                  : () => _toggleActive(id, isActive),
                              icon: Icon(
                                isActive
                                    ? Icons.power_settings_new
                                    : Icons.refresh,
                                color: isActive ? Colors.red : Colors.green,
                                size: 20,
                              ),
                              label: Text(
                                isActive ? "Nonaktifkan" : "Aktifkan",
                                style: TextStyle(
                                  color: isActive ? Colors.red : Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
