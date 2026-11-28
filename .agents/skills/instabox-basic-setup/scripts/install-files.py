# One-time config copying, run as the sandbox user. This is not Secret delivery.
import json
import os
import stat
import sys

HOME = '/data/home'
MARKER = 'INSTABOX-BASIC-SETUP '
DIRECTORY = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW


def valid_path(path):
    return (isinstance(path, str) and 0 < len(path) <= 255
            and not any(ord(c) < 32 or ord(c) == 127 or c == '\\' for c in path)
            and all(p and p != '.' and not p.startswith('..') for p in path.split('/')))


def install_files(files, home=HOME):
    results = []
    for entry in files:
        path = entry.get('path')
        result = {'path': path, 'status': 'failed'}
        results.append(result)
        if not valid_path(path) or not isinstance(entry.get('text'), str):
            continue
        data = entry['text'].encode('utf-8')
        if len(data) > 64 * 1024 or b'\x00' in data:
            continue
        fd = None
        temporary = None
        try:
            fd = os.open(home, DIRECTORY)
            parts = path.split('/')
            for part in parts[:-1]:
                try:
                    os.mkdir(part, 0o700, dir_fd=fd)
                except FileExistsError:
                    pass
                child = os.open(part, DIRECTORY, dir_fd=fd)
                os.close(fd)
                fd = child
            name = parts[-1]
            try:
                current = os.stat(name, dir_fd=fd, follow_symlinks=False)
                if not stat.S_ISREG(current.st_mode):
                    continue
            except FileNotFoundError:
                pass
            temporary = '.instabox-setup-' + os.urandom(8).hex()
            output = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
            with os.fdopen(output, 'wb') as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
                os.fchmod(stream.fileno(), 0o600)
            os.rename(temporary, name, src_dir_fd=fd, dst_dir_fd=fd)
            temporary = None
            result['status'] = 'written'
        except Exception:
            # The remote shell and filesystem are untrusted. Return only fixed
            # outcomes; exception text and config contents never reach logs.
            pass
        finally:
            if fd is not None:
                if temporary:
                    try:
                        os.unlink(temporary, dir_fd=fd)
                    except OSError:
                        pass
                os.close(fd)
    return results


if __name__ == '__main__':
    try:
        payload = json.load(sys.stdin)
        result = install_files(payload['files'])
        sys.stdout.write(MARKER + json.dumps({'files': result}) + '\n')
        sys.exit(0 if all(item['status'] == 'written' for item in result) else 1)
    except Exception:
        sys.stdout.write(MARKER + '{"error":"config copy failed"}\n')
        sys.exit(1)
