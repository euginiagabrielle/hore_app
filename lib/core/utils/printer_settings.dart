import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettings extends StatefulWidget {
  const PrinterSettings({super.key});

  @override
  State<PrinterSettings> createState() => _PrinterSettingsState();
}

class _PrinterSettingsState extends State<PrinterSettings> {
  List<Printer> _printers = [];
  String? _savedPrinterUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  // Ambil daftar printer & cek printer yg sdh tersimpan
  Future<void> _loadPrinters() async {
    setState(() => _isLoading = true);

    try {
      final printers = await Printing.listPrinters();
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _printers = printers;
        _savedPrinterUrl = prefs.getString('default_printer_url');
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal loading printer: $e"), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // Simpan printer yg dipilih ke Local Storage
  Future <void> _saveDefaultPrinter(Printer printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_printer_url', printer.url);
    await prefs.setString('default_printer_name', printer.name);

    setState(() {
      _savedPrinterUrl = printer.url;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printer ${printer.name} berhasil disimpan!'), backgroundColor: Colors.green,),
      );
    }
  }

  Future<void> _clearPrinterSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_printer_url');
    await prefs.remove('default_printer_name');

    setState(() {
      _savedPrinterUrl = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer setting dikembalikan ke mode manual.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Settings'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadPrinters, 
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Daftar Printer",
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: _savedPrinterUrl != null ? Colors.green[50] : Colors.orange[50],
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Status Direct Print:",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _savedPrinterUrl != null
                      ? "Aktif - Struk akan dicetak otomatis tanpa pop-up."
                      : "Tidak Aktif - Aplikasi akan memunculkan pop-up saat mencetak.",
                    style: TextStyle(
                      color: _savedPrinterUrl != null ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _printers.isEmpty
                ? const Center(
                    child: Text(
                      "Tidak ada printer terdeteksi. \nPastikan kabel USB/Bluetooth terhubung.", 
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _printers.length,
                    itemBuilder: (context, index) {
                      final printer = _printers[index];
                      final isSelected = printer.url == _savedPrinterUrl;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: isSelected ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isSelected ? Colors.green : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.print,
                            color: isSelected ? Colors.green : Colors.grey,
                            size: 32,
                          ),
                          title: Text(
                            printer.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            printer.isAvailable ? "Tersedia" : "Offline",
                            style: TextStyle(
                              color: printer.isAvailable ? Colors.green : Colors.red,
                            ),
                          ),
                          trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                            : null,
                          onTap: () => _saveDefaultPrinter(printer),
                        ),
                      );
                    },
                  ),
            ),

            // Reset button
            if (_savedPrinterUrl != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _clearPrinterSetting,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text("Hapus Default Printer", style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
          ],
        ),
    );
  }
}