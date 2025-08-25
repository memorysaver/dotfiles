#!/usr/bin/env python3
"""
Claude Code Stop Hook - Task Completion Notification
Plays work-complete.mp3 when Claude Code finishes responding to a task
"""

import json
import sys
import subprocess
import os
from pathlib import Path

def play_audio_macos(audio_path):
    """Play audio on macOS using afplay (non-blocking)"""
    try:
        subprocess.Popen(['afplay', str(audio_path)], 
                        stdout=subprocess.DEVNULL, 
                        stderr=subprocess.DEVNULL)
        return True
    except FileNotFoundError:
        return False

def play_audio_fallback(audio_path):
    """Fallback audio playback using pygame (non-blocking)"""
    try:
        import pygame
        import threading
        
        def play_in_thread():
            pygame.mixer.init()
            pygame.mixer.music.load(str(audio_path))
            pygame.mixer.music.play()
            # Let pygame handle the playback without blocking
            
        thread = threading.Thread(target=play_in_thread, daemon=True)
        thread.start()
        return True
    except (ImportError, Exception):
        return False

def play_audio(audio_path):
    """Play audio with platform-specific methods and fallbacks"""
    if not audio_path.exists():
        print(f"Audio file not found: {audio_path}", file=sys.stderr)
        return False
    
    # Try macOS afplay first (most reliable for your system)
    if play_audio_macos(audio_path):
        return True
    
    # Try pygame fallback
    if play_audio_fallback(audio_path):
        return True
    
    print("Failed to play audio - no suitable audio backend found", file=sys.stderr)
    return False

def main():
    try:
        # Read JSON input from Claude Code
        input_data = json.loads(sys.stdin.read()) if not sys.stdin.isatty() else {}
        
        # Determine audio file path
        dotfiles_path = Path.home() / '.dotfiles'
        soundtrack_path = dotfiles_path / 'soundtrack' / 'work-complete.mp3'
        
        # Play completion sound
        success = play_audio(soundtrack_path)
        
        if success:
            print("✅ Task completed!", file=sys.stdout)
        
        # Always exit successfully to not interfere with Claude Code
        sys.exit(0)
        
    except Exception as e:
        print(f"Stop hook error: {e}", file=sys.stderr)
        sys.exit(0)  # Don't block Claude Code on errors

if __name__ == "__main__":
    main()