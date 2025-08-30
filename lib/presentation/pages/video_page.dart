import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/theme.dart';

/// Video page for MJPEG stream viewing
class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key});

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  final _urlController = TextEditingController();
  bool _isConnected = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = 'http://192.168.1.100:8080/video';
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showVideoSettings,
            tooltip: 'Video settings',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection controls
            _buildConnectionControls(),
            
            const SizedBox(height: AppTheme.space16),
            
            // Video feed area
            Expanded(
              child: _buildVideoArea(),
            ),
            
            const SizedBox(height: AppTheme.space16),
            
            // Stream info
            _buildStreamInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stream URL',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'Enter MJPEG stream URL',
                prefixIcon: Icon(Icons.link),
              ),
              enabled: !_isConnected && !_isConnecting,
            ),
            const SizedBox(height: AppTheme.space12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _toggleConnection,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isConnected ? Icons.stop : Icons.play_arrow),
                    label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: _isConnected
                          ? Theme.of(context).colorScheme.onError
                          : Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                IconButton(
                  onPressed: _isConnected ? _takeSnapshot : null,
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'Take snapshot',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoArea() {
    return Card(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: _isConnected
            ? _buildConnectedView()
            : _buildDisconnectedView(),
      ),
    );
  }

  Widget _buildConnectedView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Stack(
        children: [
          // Video placeholder (in real app, this would be the MJPEG widget)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[900],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam,
                    size: 64,
                    color: Colors.white70,
                  ),
                  SizedBox(height: AppTheme.space16),
                  Text(
                    'Live Video Stream',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: AppTheme.space8),
                  Text(
                    'MJPEG feed would display here',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Overlay controls
          Positioned(
            top: AppTheme.space16,
            right: AppTheme.space16,
            child: _buildVideoOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.space16),
          Text(
            'No Video Feed',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Enter a stream URL and click Connect to start viewing',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoOverlay() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live indicator
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: AppTheme.space16),
          // Quality indicator
          const Text(
            'HD',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamInfo() {
    if (!_isConnected) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space8),
                Text(
                  'Stream Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoItem(label: 'Resolution', value: '1920x1080'),
                _InfoItem(label: 'FPS', value: '30'),
                _InfoItem(label: 'Latency', value: '156ms'),
                _InfoItem(label: 'Quality', value: 'High'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      setState(() {
        _isConnected = false;
      });
    } else {
      setState(() {
        _isConnecting = true;
      });
      
      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });
    }
  }

  void _takeSnapshot() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Snapshot saved to gallery'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showVideoSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Video Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.space16),
            ListTile(
              leading: const Icon(Icons.hd),
              title: const Text('Video Quality'),
              subtitle: const Text('High Definition'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over),
              title: const Text('Audio'),
              subtitle: const Text('Enabled'),
              trailing: Switch(value: true, onChanged: (value) {}),
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Fullscreen Mode'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// Info item widget for stream statistics
class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}