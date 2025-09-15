// Create a new file: lib/debug/audio_debug.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/service/audio_service.dart';

class AudioDebugScreen extends StatelessWidget {
  const AudioDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AudioService audioService = Get.find<AudioService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Debug'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Test All Audio Files',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Music Tests
            const Text('🎵 Music Tests:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => audioService.playMusic('menu'),
                  child: const Text('Play Menu Music'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => audioService.playMusic('game'),
                  child: const Text('Play Game Music'),
                ),
              ],
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => audioService.stopMusic(),
                  child: const Text('Stop Music'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => audioService.pauseMusic(),
                  child: const Text('Pause Music'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // SFX Tests
            const Text('🔊 SFX Tests:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 3,
                children: [
                  _buildSfxButton('Button Click', () => audioService.playButtonClick()),
                  _buildSfxButton('Eat Food', () => audioService.playEatFood()),
                  _buildSfxButton('Death', () => audioService.playDeath()),
                  _buildSfxButton('Kill', () => audioService.playKill()),
                  _buildSfxButton('Boost On', () => audioService.playBoostOn()),
                  _buildSfxButton('Boost Off', () => audioService.playBoostOff()),
                  _buildSfxButton('Revive', () => audioService.playRevive()),
                  _buildSfxButton('Game Over', () => audioService.playGameOver()),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Audio Settings
            Obx(() => Column(
              children: [
                Text('Music Enabled: ${audioService.isMusicEnabled.value}'),
                Switch(
                  value: audioService.isMusicEnabled.value,
                  onChanged: (_) => audioService.toggleMusic(),
                ),
                Text('SFX Enabled: ${audioService.isSfxEnabled.value}'),
                Switch(
                  value: audioService.isSfxEnabled.value,
                  onChanged: (_) => audioService.toggleSfx(),
                ),
                // Text('Music Volume: ${audioService.musicVolume.value.toStringAsFixed(2)}'),
                // Slider(
                //   value: audioService.musicVolume.value,
                //   onChanged: (value) => audioService.setMusicVolume(value),
                // ),
                // Text('SFX Volume: ${audioService.sfxVolume.value.toStringAsFixed(2)}'),
                // Slider(
                //   value: audioService.sfxVolume.value,
                //   onChanged: (value) => audioService.setSfxVolume(value),
                // ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSfxButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

// Add this route to your app_pages.dart for easy access
// GetPage(
//   name: '/audio-debug',
//   page: () => const AudioDebugScreen(),
// ),