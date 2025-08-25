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

def get_last_prompt_from_cache(input_data):
    """Get the last prompt from Claude's global cache with session fallback"""
    try:
        claude_dir = Path.home() / '.claude'
        
        # Try session-specific cache first if session_id available
        session_id = input_data.get('session_id')
        if session_id and session_id != 'unknown':
            session_cache = claude_dir / 'prompts' / f'{session_id}.txt'
            if session_cache.exists():
                with open(session_cache, 'r') as f:
                    last_prompt = f.read().strip()
                    if last_prompt:
                        return format_completion_message(last_prompt)
        
        # Fallback to simple cache
        simple_cache = claude_dir / 'last_prompt.txt'
        if simple_cache.exists():
            with open(simple_cache, 'r') as f:
                last_prompt = f.read().strip()
                if last_prompt:
                    return format_completion_message(last_prompt)
                    
    except Exception:
        pass
    return "Task completed successfully! ✅"

def format_completion_message(prompt):
    """Format the completion message with proper truncation"""
    if len(prompt) > 50:
        return f"Completed: {prompt[:50]}..."
    else:
        return f"Completed: {prompt}"

def main():
    try:
        # Read JSON input from Claude Code
        input_data = json.loads(sys.stdin.read()) if not sys.stdin.isatty() else {}
        
        # Optional debug logging (redirected to Claude's debug directory)
        try:
            debug_dir = Path.home() / '.claude' / 'debug'
            debug_dir.mkdir(exist_ok=True)
            debug_log = debug_dir / 'stop_debug.json'
            with open(debug_log, 'w') as f:
                json.dump(input_data, f, indent=2)
        except Exception:
            pass  # Don't fail if debug logging fails
        
        # Get work summary from prompt cache
        work_summary = get_last_prompt_from_cache(input_data)
        
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