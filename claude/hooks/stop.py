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

def show_macos_notification(title, message, subtitle=None):
    """Show native macOS notification"""
    try:
        cmd = ['osascript', '-e']
        applescript = f'display notification "{message}" with title "{title}"'
        if subtitle:
            applescript += f' subtitle "{subtitle}"'
        
        subprocess.Popen(cmd + [applescript], 
                        stdout=subprocess.DEVNULL, 
                        stderr=subprocess.DEVNULL)
        return True
    except Exception:
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

def extract_work_summary(input_data):
    """Extract meaningful work summary from stop hook data"""
    # Get session info
    session_id = input_data.get('session_id', 'unknown')
    prompts = input_data.get('prompts', [])
    
    # Get the most recent prompt for context
    if prompts:
        last_prompt = prompts[-1][:50] + "..." if len(prompts[-1]) > 50 else prompts[-1]
        return f"Completed: {last_prompt}"
    
    return "Task completed successfully! ✅"

def main():
    try:
        # Read JSON input from Claude Code
        input_data = json.loads(sys.stdin.read()) if not sys.stdin.isatty() else {}
        
        # Extract work summary
        work_summary = extract_work_summary(input_data)
        
        # Determine audio file path
        dotfiles_path = Path.home() / '.dotfiles'
        soundtrack_path = dotfiles_path / 'soundtrack' / 'work-complete.mp3'
        
        # Play completion sound & show notification
        audio_success = play_audio(soundtrack_path)
        notification_success = show_macos_notification(
            "Claude Code", 
            work_summary, 
            "Work Complete"
        )
        
        if audio_success or notification_success:
            print(f"✅ {work_summary}", file=sys.stdout)
        
        # Always exit successfully to not interfere with Claude Code
        sys.exit(0)
        
    except Exception as e:
        print(f"Stop hook error: {e}", file=sys.stderr)
        sys.exit(0)  # Don't block Claude Code on errors

if __name__ == "__main__":
    main()