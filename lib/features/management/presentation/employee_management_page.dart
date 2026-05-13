import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/employee_repository.dart';
import '../../../core/utils/error_handler.dart';

class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({super.key});

  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  final EmployeeRepository _repository = EmployeeRepository();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  bool _isCurrentUserOwner = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeAndFetchEmployee();
    });
  }

  Future<void> _initializeAndFetchEmployee() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _currentUserId = user.id;

        final myData = await _supabase
          .from('employees')
          .select('employee_role, is_trusted')
          .eq('auth_user_id', user.id)
          .maybeSingle();

        if (myData != null) {
          _isCurrentUserOwner = myData['employee_role'] == 'owner';
          final bool isTrusted = myData['is_trusted'] == true;

          // Jika bukan owner DAN bukan trusted staff, tendang keluar
          if (!_isCurrentUserOwner && !isTrusted) {
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Akses Ditolak: Anda bukan Trusted Staff."))
              );
            }
            return;
          }
        }
      }
      
      final data = await _repository.getEmployees(isOwner: _isCurrentUserOwner);
      
      if (mounted) {
        setState(() {
          _employees = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e))));
      }
    }
  }

  void _showAddEmployeeDialog() {
    final nipController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    
    String selectedRole = 'sales';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Tambah Pegawai Baru"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nipController,
                  decoration: const InputDecoration(labelText: "NIP", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: "Posisi / Role", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text("Admin")),
                    DropdownMenuItem(value: 'kasir', child: Text("Kasir")),
                    DropdownMenuItem(value: 'sales', child: Text("Sales")),
                  ],
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                const Divider(height: 30, thickness: 1),
                const Text("Data Login Aplikasi", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email Login", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password Sementara", border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nipController.text.isEmpty || nameController.text.isEmpty || 
                    emailController.text.isEmpty || passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua kolom wajib diisi!")));
                  return;
                }
                
                setDialogState(() => isSaving = true);
                try {
                  await _repository.addEmployee(
                    nip: nipController.text.trim(),
                    name: nameController.text.trim(),
                    role: selectedRole,
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    _initializeAndFetchEmployee();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Pegawai berhasil didaftarkan!"), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(e)), backgroundColor: Colors.red));
                }
              },
              child: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Simpan & Daftarkan"),
            ),
          ],
        ),
      ),
    );
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
    if (id == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak bisa mengubah otoritas sendiri!")));
      return;
    }

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
      await _initializeAndFetchEmployee();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status kepercayaan berhasil diubah!")),
        );
      }
    } catch (e) {
      // If fail, return to previous UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleActive(String id, bool currentValue) async {
    if (id == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak bisa menonaktifkan akun sendiri!")));
      return;
    }

    // show pop-up
    final bool confirm = await _showConfirmation(
      currentValue ? "Nonaktifkan Pegawai?" : "Aktifkan Pegawai",
      currentValue ? "Pegawai ini dinonaktifkan." : "Pegawai ini diaktifkan.",
    );

    if (!confirm) return;

    try {
      await _repository.updateActiveStatus(id, !currentValue);
      await _initializeAndFetchEmployee();
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
      appBar: AppBar(
        title: const Text("Manajemen Pegawai"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _initializeAndFetchEmployee),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _initializeAndFetchEmployee,
              child: _employees.isEmpty
                  ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text("Belum ada data pegawai.")))])
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 100), 
                      itemCount: _employees.length,
                      itemBuilder: (context, index) {
                        final employee = _employees[index];

                        final String name = employee['employee_name'] ?? 'No Name';
                        final String role = employee['employee_role'];
                        final bool isTargetOwner = role == 'owner';
                        final String email = employee['email'] ?? '-';
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
                                              decoration: isActive ? null : TextDecoration.lineThrough,
                                              color: isActive ? Colors.black : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "NIP: $nip | Role: ${role.toUpperCase()}",
                                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                                    // Trusted Toggle
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

                                    // Active Toggle
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
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeDialog,
        icon: const Icon(Icons.person_add),
        label: const Text("Tambah Pegawai"),
      ),
    );
  }
}
