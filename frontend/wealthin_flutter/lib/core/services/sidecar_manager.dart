import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path/path.dart' as path;

/// Sidecar Manager - Manages Python Backend Lifecycle
/// Automatically starts, monitors, and restarts the backend process
///
/// Features:
/// - PID file management for process tracking
/// - Log file output for debugging
/// - Auto-restart on crash with backoff
/// - Graceful shutdown handling
class SidecarManager {
  SidecarManager._internal();
  static final SidecarManager _instance = SidecarManager._internal();
  factory SidecarManager() => _instance;

  Process? _backendProcess;
  Timer? _healthCheckTimer;
  IOSink? _logSink;
  bool _isRunning = false;
  int _restartCount = 0;
  static const int _maxRestarts = 3;
  static const Duration _healthCheckInterval = Duration(seconds: 30);

  // File names for process management
  static const String _pidFileName = 'sidecar.pid';
  static const String _logFileName = 'sidecar.log';

  /// Whether the sidecar is currently running
  bool get isRunning => _isRunning;

  /// Get the backend directory path based on platform
  String? get _backendDir {
    if (kIsWeb) return null; // Web doesn't support local processes

    try {
      // Get the project root directory
      // In development: navigate from flutter app to wealthin_agents
      // In production: backend would be bundled in a known location

      final executableDir = path.dirname(Platform.resolvedExecutable);
      
      // Development mode: Look for wealthin_agents relative to project
      final projectRoot = _findProjectRoot();
      if (projectRoot != null) {
        final agentsPath = path.join(projectRoot, 'wealthin_agents');
        if (Directory(agentsPath).existsSync()) {
          return agentsPath;
        }
      }

      // Production mode: Look in bundled location
      final bundledPath = path.join(executableDir, 'data', 'wealthin_agents');
      if (Directory(bundledPath).existsSync()) {
        return bundledPath;
      }

      // Fallback: Check common development locations
      // Fallback: Check common development locations
      final devPaths = [
        '/media/nikhil/427092fa-e2b4-41f9-aa94-fa27c0b84b171/wealthin_git_/wealthin_v2/backend',
        path.join(Directory.current.path, '..', 'backend'),
        path.join(Directory.current.path, '..', '..', 'backend'),
        '/media/nikhil/427092fa-e2b4-41f9-aa94-fa27c0b84b171/wealthin_git_/wealthin_v2/wealthin_agents',
      ];

      for (final p in devPaths) {
        if (Directory(p).existsSync()) {
          return path.normalize(p);
        }
      }
    } catch (e) {
      debugPrint('[Sidecar] Error finding backend directory: $e');
    }
    return null;
  }

  /// Find the project root by looking for known markers
  String? _findProjectRoot() {
    try {
      var current = Directory.current;
      for (int i = 0; i < 5; i++) {
        // Look for wealthin_v2 directory structure
        final agents = Directory(path.join(current.path, 'wealthin_agents'));
        if (agents.existsSync()) {
          return current.path;
        }
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
      }
    } catch (e) {
      debugPrint('[Sidecar] Error finding project root: $e');
    }
    return null;
  }

  /// Get the PID file path
  String? get _pidFilePath {
    final backendDir = _backendDir;
    if (backendDir == null) return null;
    return path.join(backendDir, _pidFileName);
  }

  /// Get the log file path
  String? get _logFilePath {
    final backendDir = _backendDir;
    if (backendDir == null) return null;
    return path.join(backendDir, _logFileName);
  }

  /// Write PID to file for external tracking
  Future<void> _writePidFile(int pid) async {
    final pidPath = _pidFilePath;
    if (pidPath == null) return;
    try {
      await File(pidPath).writeAsString('$pid');
      debugPrint('[Sidecar] PID $pid written to $pidPath');
    } catch (e) {
      debugPrint('[Sidecar] Failed to write PID file: $e');
    }
  }

  /// Read PID from file (check for existing process)
  Future<int?> _readPidFile() async {
    final pidPath = _pidFilePath;
    if (pidPath == null) return null;
    try {
      final file = File(pidPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return int.tryParse(content.trim());
      }
    } catch (e) {
      debugPrint('[Sidecar] Failed to read PID file: $e');
    }
    return null;
  }

  /// Delete PID file on shutdown
  Future<void> _deletePidFile() async {
    final pidPath = _pidFilePath;
    if (pidPath == null) return;
    try {
      final file = File(pidPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[Sidecar] PID file deleted');
      }
    } catch (e) {
      debugPrint('[Sidecar] Failed to delete PID file: $e');
    }
  }

  /// Check if a process with given PID is running
  Future<bool> _isProcessRunning(int pid) async {
    try {
      // On Unix, sending signal 0 checks if process exists
      final result = await Process.run('kill', ['-0', '$pid']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Kill existing backend process from PID file
  Future<void> _killExistingProcess() async {
    final pid = await _readPidFile();
    if (pid != null && await _isProcessRunning(pid)) {
      debugPrint('[Sidecar] Killing existing backend process (PID: $pid)');
      try {
        Process.killPid(pid, ProcessSignal.sigterm);
        await Future.delayed(const Duration(seconds: 2));
        if (await _isProcessRunning(pid)) {
          Process.killPid(pid, ProcessSignal.sigkill);
        }
      } catch (e) {
        debugPrint('[Sidecar] Failed to kill existing process: $e');
      }
    }
    await _deletePidFile();
  }

  /// Open log file for writing
  Future<void> _openLogFile() async {
    final logPath = _logFilePath;
    if (logPath == null) return;
    try {
      _logSink = File(logPath).openWrite(mode: FileMode.append);
      _logSink?.writeln('\n=== Sidecar started at ${DateTime.now()} ===');
    } catch (e) {
      debugPrint('[Sidecar] Failed to open log file: $e');
    }
  }

  /// Close log file
  Future<void> _closeLogFile() async {
    await _logSink?.flush();
    await _logSink?.close();
    _logSink = null;
  }

  /// Get the Python executable path
  String get _pythonPath {
    // Check for virtual environment first
    final backendDir = _backendDir;
    if (backendDir != null) {
      // Check project-level venv
      final projectVenv = path.join(path.dirname(backendDir), '.venv', 'bin', 'python');
      if (File(projectVenv).existsSync()) {
        return projectVenv;
      }
      
      // Check local venv in agents directory
      final localVenv = path.join(backendDir, '.venv', 'bin', 'python');
      if (File(localVenv).existsSync()) {
        return localVenv;
      }
    }
    
    // Fallback to system Python
    return 'python3';
  }

  /// Start the backend sidecar process
  Future<bool> start() async {
    if (kIsWeb) {
      debugPrint('[Sidecar] Web platform - skipping backend start');
      return false;
    }

    if (_isRunning && _backendProcess != null) {
      debugPrint('[Sidecar] Backend already running');
      return true;
    }

    final backendDir = _backendDir;
    if (backendDir == null) {
      debugPrint('[Sidecar] Backend directory not found');
      return false;
    }

    // Kill any existing backend process from previous run
    await _killExistingProcess();

    debugPrint('[Sidecar] Starting backend from: $backendDir');
    debugPrint('[Sidecar] Using Python: $_pythonPath');

    // Open log file for output
    await _openLogFile();

    try {
      // 1. Production Mode: Check for compiled executable
      final executableExt = Platform.isWindows ? '.exe' : '';
      final executableName = 'wealthin_server$executableExt';
      
      // Look for executable in the same directory as the main app or in data/
      String? executablePath;
      
      // List of potential paths for the bundled executable
      final potentialPaths = [
        path.join(path.dirname(Platform.resolvedExecutable), executableName),
        path.join(path.dirname(Platform.resolvedExecutable), 'data', executableName),
        path.join(backendDir, 'dist', executableName),
      ];

      for (final p in potentialPaths) {
        if (File(p).existsSync()) {
          executablePath = p;
          break;
        }
      }

      if (executablePath != null) {
        debugPrint('[Sidecar] Found compiled backend: $executablePath');
        _backendProcess = await Process.start(
          executablePath,
          [], // No args needed for freeze exe usually, or passing port if configured
          workingDirectory: path.dirname(executablePath),
          runInShell: false,
        );
      } else {
        // 2. Development Mode: Run Python Script
        debugPrint('[Sidecar] No compiled backend found. Using Python script.');
        
        _backendProcess = await Process.start(
          _pythonPath,
          ['-m', 'uvicorn', 'main:app', '--host', '0.0.0.0', '--port', '8000'],
          workingDirectory: backendDir,
          environment: {
            ...Platform.environment,
            'PYTHONUNBUFFERED': '1', // Ensure real-time output
          },
        );
      }

      _isRunning = true;
      final pid = _backendProcess!.pid;
      debugPrint('[Sidecar] Backend process started (PID: $pid)');

      // Write PID file for external tracking
      await _writePidFile(pid);

      // Listen to stdout and write to log file
      _backendProcess!.stdout.transform(const SystemEncoding().decoder).listen(
        (data) {
          for (final line in data.split('\n')) {
            if (line.trim().isNotEmpty) {
              debugPrint('[Backend] $line');
              _logSink?.writeln('[${DateTime.now().toIso8601String()}] $line');
            }
          }
        },
      );

      // Listen to stderr and write to log file
      _backendProcess!.stderr.transform(const SystemEncoding().decoder).listen(
        (data) {
          for (final line in data.split('\n')) {
            if (line.trim().isNotEmpty) {
              debugPrint('[Backend:ERR] $line');
              _logSink?.writeln('[${DateTime.now().toIso8601String()}] ERR: $line');
            }
          }
        },
      );

      // Monitor process exit
      _backendProcess!.exitCode.then((exitCode) async {
        debugPrint('[Sidecar] Backend exited with code: $exitCode');
        _logSink?.writeln('[${DateTime.now().toIso8601String()}] Backend exited with code: $exitCode');
        _isRunning = false;
        _backendProcess = null;

        // Clean up PID file and log
        await _deletePidFile();
        await _closeLogFile();

        // Auto-restart if crashed unexpectedly
        if (exitCode != 0 && _restartCount < _maxRestarts) {
          _restartCount++;
          debugPrint('[Sidecar] Auto-restarting backend (attempt $_restartCount/$_maxRestarts)');
          Future.delayed(const Duration(seconds: 2), () => start());
        }
      });

      // Start health check timer
      _startHealthCheck();

      // Reset restart count on successful start
      _restartCount = 0;

      // Wait a moment for the server to initialize
      await Future.delayed(const Duration(seconds: 2));

      return true;
    } catch (e) {
      debugPrint('[Sidecar] Failed to start backend: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Start periodic health checks
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) async {
      if (!_isRunning) return;
      
      // Simple check: is process still running?
      // The BackendConfig handles actual HTTP health checks
      if (_backendProcess == null) {
        debugPrint('[Sidecar] Backend process died, attempting restart');
        start();
      }
    });
  }

  /// Stop the backend sidecar process
  Future<void> stop() async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    if (_backendProcess != null) {
      final pid = _backendProcess!.pid;
      debugPrint('[Sidecar] Stopping backend (PID: $pid)');
      _logSink?.writeln('[${DateTime.now().toIso8601String()}] Stopping backend...');

      // Send SIGTERM for graceful shutdown
      _backendProcess!.kill(ProcessSignal.sigterm);

      // Wait for graceful exit
      try {
        await _backendProcess!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Force kill if graceful shutdown fails
            debugPrint('[Sidecar] Force killing backend');
            _backendProcess!.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      } catch (e) {
        debugPrint('[Sidecar] Error stopping backend: $e');
      }

      _backendProcess = null;
      _isRunning = false;

      // Clean up PID file and log
      await _deletePidFile();
      await _closeLogFile();

      debugPrint('[Sidecar] Backend stopped');
    }
  }

  /// Check if the backend process is healthy
  bool checkHealth() {
    return _isRunning && _backendProcess != null;
  }
}

/// Global sidecar manager instance
final sidecarManager = SidecarManager();
