#!/usr/bin/env python3
"""Adopt a healthy local Herdr server; launch the native server only when absent."""
import argparse
import errno
import json
from pathlib import Path
import re
import shutil
import socket
import subprocess
import time
import uuid


def alive(socket_path):
    request_id = str(uuid.uuid4())
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as stream:
            stream.settimeout(3)
            stream.connect(str(socket_path))
            stream.sendall((json.dumps({'id': request_id, 'method': 'ping', 'params': {}}) + '\n').encode())
            with stream.makefile() as reader:
                for line in reader:
                    response = json.loads(line)
                    if response.get('id') == request_id:
                        if 'error' in response:
                            raise RuntimeError('Herdr health protocol failed; preserve the existing server')
                        if response.get('result', {}).get('type') != 'pong':
                            raise RuntimeError('Unexpected health response; preserve the existing server')
                        return True
        raise RuntimeError('Herdr closed health connection; inspect it before starting a replacement')
    except OSError as error:
        if error.errno in (errno.ENOENT, errno.ECONNREFUSED):
            return False
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', default=shutil.which('herdr'))
    parser.add_argument('--session', default='default')
    parser.add_argument('--once', action='store_true')
    args = parser.parse_args()
    if not args.binary or not re.fullmatch(r'[a-zA-Z0-9_-]+', args.session):
        parser.error('Herdr binary and valid local session are required')
    base = Path.home() / '.config/herdr'
    if args.session != 'default':
        base = base / 'sessions' / args.session
    command = [args.binary]
    if args.session != 'default':
        command += ['--session', args.session]
    command += ['server']
    child = None
    previous = None
    while True:
        try:
            healthy = alive(base / 'herdr.sock')
            if not healthy and (child is None or child.poll() is not None):
                child = subprocess.Popen(command)
                print('Launching the configured local Herdr server', flush=True)
            if healthy and previous is not True:
                print('Local Herdr server healthy; preserving existing panes', flush=True)
            previous = healthy
            if args.once:
                if not healthy:
                    raise RuntimeError('Server launch submitted; readiness not yet verified')
                return
        except (OSError, RuntimeError, ValueError) as error:
            if args.once:
                raise
            message = str(error)
            if message != previous:
                print(message, flush=True)
            previous = message
        time.sleep(5)


if __name__ == '__main__':
    main()
