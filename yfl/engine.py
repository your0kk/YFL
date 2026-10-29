from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import stat
import time
import uuid
import zipfile
from dataclasses import asdict, dataclass
from pathlib import Path
from xml.etree import ElementTree as ET

SUPPORTED = {'.pdf', '.docx', '.xlsx', '.xlsm', '.pptx', '.txt', '.md', '.rtf', '.doc', '.ppt', '.xls', '.odt', '.ods', '.odp'}
SKIP = {'.git', '.vs', '.idea', '.vscode', 'node_modules', 'vendor', 'bin', 'obj', 'build', 'dist', 'library', 'packages', 'appdata', 'windows', 'program files', 'program files (x86)', '.venv', 'venv', '__pycache__', 'file organizer', 'порядок на пк', 'lists', 'config', 'cache', 'logs', '_internal', 'mods', 'minecraft rus'}
PROJECT_MARKERS = {'package.json', 'pyproject.toml', '.git', '.obsidian', 'project.godot', 'ProjectSettings', 'Cargo.toml', 'go.mod'}
LIMIT = 2_000_000


def state_dir():
    p = Path(os.environ.get('LOCALAPPDATA', Path.home() / '.local' / 'share')) / 'YFL'
    p.mkdir(parents=True, exist_ok=True)
    return p


def normalized(text):
    return re.sub(r'\s+', ' ', text.casefold().replace('ё', 'е')).strip()


def other_author(text):
    for match in re.finditer(r'\b(?i:выполнил\s*а?|выполнен[ао]?|разработал[аи]?)\b', text[:2500]):
        tail = text[match.end():match.end() + 220]
        tail = re.split(r'(?i:провер|руководител|содержан|новосибирск|20\d{2}|_{3,})', tail)[0]
        if re.search(r'\b[А-ЯЁ][а-яё]{2,}\s+(?:[А-ЯЁ]\s*[.]\s*[А-ЯЁ]\s*[.]|[А-ЯЁ][а-яё]{2,}\s+[А-ЯЁ][а-яё]{3,})', tail):
            return True
    return False


def xml_text(blob):
    return ' '.join(s.strip() for s in ET.fromstring(blob).itertext() if s.strip())


def extract(path):
    ext = path.suffix.lower()
    if path.stat().st_size > 80 * 1024 * 1024:
        return '', 'Файл больше 80 МБ: содержимое не прочитано'
    try:
        if ext == '.pdf':
            from pypdf import PdfReader
            reader = PdfReader(str(path), strict=False)
            if reader.is_encrypted and not reader.decrypt(''):
                return '', 'PDF защищён паролем'
            count = len(reader.pages)
            indices = sorted(set(range(min(count, 10))) | set(range(max(10, count - 2), count)))
            text = '\n'.join(reader.pages[n].extract_text() or '' for n in indices)[:LIMIT]
            return text, 'Прочитан текст PDF' if text.strip() else 'Нет текстового слоя: нужен OCR'
        if ext in {'.docx', '.pptx', '.xlsx', '.xlsm', '.odt', '.ods', '.odp'}:
            with zipfile.ZipFile(path) as z:
                if sum(i.file_size for i in z.infolist()) > 150 * 1024 * 1024:
                    return '', 'Слишком большой распакованный документ'
                if ext == '.docx':
                    names = ['word/document.xml']
                elif ext == '.pptx':
                    names = sorted([n for n in z.namelist() if re.fullmatch(r'ppt/slides/slide\d+\.xml', n)], key=lambda n: int(re.search(r'(\d+)\.xml', n)[1]))
                elif ext in {'.xlsx', '.xlsm'}:
                    names = [n for n in z.namelist() if n == 'xl/sharedStrings.xml' or re.fullmatch(r'xl/worksheets/sheet\d+\.xml', n)]
                else:
                    names = ['content.xml']
                text = '\n'.join(xml_text(z.read(n)) for n in names if n in z.namelist())[:LIMIT]
                return text, 'Прочитано содержимое документа'
        if ext == '.rtf':
            from striprtf.striprtf import rtf_to_text
            return rtf_to_text(path.read_bytes().decode('cp1251', errors='replace'))[:LIMIT], 'Прочитан RTF'
        if ext in {'.txt', '.md'}:
            blob = path.read_bytes()[:LIMIT]
            for enc in ('utf-8-sig', 'utf-16', 'cp1251'):
                try:
                    text = blob.decode(enc)
                    if '\x00' not in text:
                        return text, 'Прочитан текст'
                except UnicodeError:
                    pass
        return '', 'Старый формат: требуется DOCX, XLSX или PPTX'
    except Exception as e:
        return '', 'Не удалось прочитать: ' + str(e)[:140]
    return '', 'Не удалось прочитать текст'


@dataclass
class Decision:
    source: str
    destination: str
    category: str
    kind: str
    author: str
    reason: str
    read_status: str
    size: int
    mtime_ns: int
    selected: bool = True
    status: str = 'Готов к переносу'


def classify(path, text, author, read_status):
    name = normalized(path.stem)
    head = normalized(text[:6500])
    title = normalized(text[:1800])
    whole = normalized(text)
    surname = normalized(author).split()[0] if author.strip() else ''
    author_hit = bool(surname and len(surname) >= 3 and (re.search(r'(?<![а-яa-z])' + re.escape(surname) + r'(?![а-яa-z])', name + ' ' + head) or re.search(r'(?<![а-яa-z])' + re.escape(surname) + r'[а-я]{1,2}(?![а-яa-z])', name)))
    own = 'Автор указан' if author_hit else 'Автор не определён'
    kind = 'Другие учебные материалы'
    patterns = [
        ('Курсовые', r'курсов\w*|\bкурс[._ -]?раб'),
        ('Дипломные', r'диплом\w*|выпускн\w* квалификац|\bвкр\b'),
        ('Лабораторные', r'лаборатор\w*|\bлаб[._ -]?\d|\blaba\d|тервер'),
        ('Самостоятельные', r'самостоятельн\w*'),
        ('Практические', r'практическ\w*|\bпз[._ -]?\d|\bpractice[_ -]?\d|\bпрактика[_ -]?\d'),
        ('Контрольные', r'контрольн\w* работ'),
        ('Рефераты', r'реферат\w*'),
        ('Отчёты по практике', r'отчет\w* (?:о|по) практик|дневник\w* практик'),
        ('Презентации', r'презентаци\w*'),
        ('Индивидуальные проекты', r'индивидуальн\w* (?:работ|проект|задани)|итогов\w* проект'),
    ]
    for source in (name, title):
        for label, pattern in patterns:
            if re.search(pattern, source):
                kind = label
                break
        if kind != 'Другие учебные материалы':
            break
    if path.suffix.lower() in {'.pptx', '.ppt', '.odp'} and kind == 'Другие учебные материалы':
        kind = 'Презентации'
    method_name = bool(re.search(r'методич|методическ|(?:^|[ _.-])му(?:[ _.-]|$)|образец|шаблон|инструкци|учебник|лекци|пособи|рабочая программа|пример плана|темы проектов|темы курсов', name))
    method_title = bool(re.search(r'методическ\w* (?:указания|рекомендации|пособие|разработк)|учебное пособие|учебник|конспект лекци', head))
    teacher_task = bool(re.search(r'практическое занятие|самостоятельная работа|лабораторная работа', name + ' ' + head)) and bool(re.search(r'порядок выполнения|задания для самостоятельного|задание для выполнения|контрольные вопросы|обучающийся должен|цель занятия|выполните|создайте|разработайте|составьте|ответьте|начинаем с|вводим задачу', whole))
    if method_name and not (author_hit and not method_title and re.search(r'выполнил|отчет', title)) or method_title:
        return 'Методички и задания', kind, own, 'Методичка, образец или инструкция в заголовке'
    if author_hit:
        location = 'названии' if surname in name else 'начале документа'
        return 'Мои работы', kind, own, 'Фамилия в ' + location + '; готовность работы не проверена'
    if teacher_task:
        return 'Методички и задания', kind, own, 'Задание и указания по выполнению; автор не указан'
    if other_author(text):
        return 'Работы других авторов', kind, 'Указан другой автор', 'Есть подпись исполнителя без вашей фамилии'
    if path.suffix.lower() in {'.txt', '.md'} and kind == 'Другие учебные материалы' and not re.search(r'учеб|студент|задани|алгоритм|блок.?схем|конспект', whole):
        return '', kind, own, 'Не найдено учебных признаков: оставить на месте'
    return 'Требуют проверки', kind, own, 'Недостаточно признаков автора или назначения'


def project_dir(path):
    try:
        names = {p.name for p in path.iterdir()}
        return bool(names & PROJECT_MARKERS or any(n.casefold().endswith(('.sln', '.csproj', '.blend', '.uproject', '.exe', '.dll', '.bat', '.cmd', '.py', '.js', '.ts', '.java', '.kt', '.cpp', '.html', '.sh')) for n in names) or re.search(r'(?i)(?:^|[_ -])проект(?:[_ -]|$)', path.name))
    except OSError:
        return True


def candidates(roots, output, recurse=True):
    output = output.resolve()
    seen = set()
    for root in roots:
        root = Path(root).resolve()
        if not root.is_dir():
            continue
        for current, dirs, names in os.walk(root, followlinks=False):
            current = Path(current)
            if current == output or output in current.parents:
                dirs[:] = []
                continue
            dirs[:] = [d for d in dirs if d.casefold() not in SKIP and not d.startswith('.') and not (current / d).is_symlink() and not (current / d).is_junction() and not project_dir(current / d)] if recurse else []
            for name in sorted(names):
                p = current / name
                if re.search(r'(?i)(recovery[-_ ]?codes|password|passwd|credential|secret|api[-_ ]?key|token|парол|copyright|license|^readme)', name):
                    continue
                if p.suffix.lower() not in SUPPORTED or name.startswith(('~$', '_$', '.$', '.')) or p in seen:
                    continue
                try:
                    s = p.stat(follow_symlinks=False)
                    if p.is_symlink() or s.st_file_attributes & (2 | 4 | 1024 | 4096):
                        continue
                    if time.time() - s.st_mtime < 600:
                        continue
                    seen.add(p)
                    yield p
                except OSError:
                    continue


def plan(roots, output, author, recurse=True, progress=None, cancel=None):
    output = Path(output).resolve()
    root_paths = [Path(r).resolve() for r in roots]
    if any(r == output for r in root_paths):
        raise ValueError('Папка результата должна отличаться от исходной папки')
    result = []
    used = set()
    for i, p in enumerate(candidates(roots, output, recurse), 1):
        if cancel and cancel.is_set():
            break
        if progress:
            progress(i, p.name)
        text, status = extract(p)
        category, kind, own, reason = classify(p, text, author, status)
        if not category:
            continue
        dest = output / category / kind / p.name
        n = 2
        while dest.exists() or str(dest).casefold() in used:
            dest = output / category / kind / (p.stem + f' ({n})' + p.suffix)
            n += 1
        used.add(str(dest).casefold())
        s = p.stat()
        result.append(Decision(str(p), str(dest), category, kind, own, reason, status, s.st_size, s.st_mtime_ns))
    return result


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


class Store:
    def __init__(self, folder=None):
        self.folder = Path(folder) if folder else state_dir()
        self.folder.mkdir(parents=True, exist_ok=True)
        self.db = self.folder / 'history.sqlite3'
        import sqlite3
        self.conn = sqlite3.connect(self.db, timeout=20)
        self.conn.execute('CREATE TABLE IF NOT EXISTS moves (id INTEGER PRIMARY KEY, batch TEXT, source TEXT, destination TEXT, hash TEXT, state TEXT, created REAL)')
        columns = {r[1] for r in self.conn.execute('PRAGMA table_info(moves)')}
        if 'kind' not in columns:
            self.conn.execute("ALTER TABLE moves ADD COLUMN kind TEXT DEFAULT 'file'")
        if 'identity' not in columns:
            self.conn.execute('ALTER TABLE moves ADD COLUMN identity TEXT')
        self.conn.commit()

    def move(self, decisions, progress=None, cancel=None):
        batch = str(uuid.uuid4())
        stats = {'moved': 0, 'skipped': 0, 'errors': []}
        for i, item in enumerate(decisions, 1):
            if cancel and cancel.is_set():
                break
            if not item.selected:
                continue
            if progress:
                progress(i, Path(item.source).name)
            try:
                source, dest = Path(item.source), Path(item.destination)
                s = source.stat()
                if s.st_size != item.size or s.st_mtime_ns != item.mtime_ns:
                    item.status = 'Пропущен: файл изменился'
                    stats['skipped'] += 1
                    continue
                if dest.exists():
                    raise FileExistsError('Место занято: повторите анализ')
                if source.drive.casefold() != dest.drive.casefold():
                    raise ValueError('Для безопасного возврата выберите папку на том же диске')
                sha = digest(source)
                dest.parent.mkdir(parents=True, exist_ok=True)
                cur = self.conn.execute('INSERT INTO moves(batch,source,destination,hash,state,created) VALUES(?,?,?,?,?,?)', (batch, str(source), str(dest), sha, 'planned', time.time()))
                self.conn.commit()
                if source.stat().st_size != s.st_size or source.stat().st_mtime_ns != s.st_mtime_ns:
                    raise ValueError('Файл изменился во время проверки')
                os.rename(source, dest)
                self.conn.execute('UPDATE moves SET state=? WHERE id=?', ('moved', cur.lastrowid))
                self.conn.commit()
                item.status = 'Перемещён'
                stats['moved'] += 1
            except Exception as e:
                item.status = 'Ошибка: ' + str(e)
                stats['errors'].append({'file': item.source, 'error': str(e)})
        return stats

    def move_paths(self, pairs):
        batch = str(uuid.uuid4())
        moved = []
        for source, dest in pairs:
            source, dest = Path(source), Path(dest)
            if not source.exists() or source.is_symlink() or source.is_junction():
                raise ValueError('Исходный путь отсутствует или является ссылкой: ' + str(source))
            if dest.exists() or source.resolve() in dest.resolve().parents:
                raise ValueError('Недопустимая папка назначения: ' + str(dest))
            if source.drive.casefold() != dest.drive.casefold():
                raise ValueError('Перенос между дисками не поддерживается')
            kind = 'directory' if source.is_dir() else 'file'
            sha = '' if kind == 'directory' else digest(source)
            identity = str(source.stat().st_ino)
            dest.parent.mkdir(parents=True, exist_ok=True)
            cur = self.conn.execute('INSERT INTO moves(batch,source,destination,hash,state,created,kind,identity) VALUES(?,?,?,?,?,?,?,?)', (batch, str(source), str(dest), sha, 'planned', time.time(), kind, identity))
            self.conn.commit()
            os.rename(source, dest)
            self.conn.execute('UPDATE moves SET state=? WHERE id=?', ('moved', cur.lastrowid))
            self.conn.commit()
            moved.append({'source': str(source), 'destination': str(dest)})
        return moved

    def undo(self):
        row = self.conn.execute("SELECT batch FROM moves WHERE state IN ('moved','planned') ORDER BY id DESC LIMIT 1").fetchone()
        if not row:
            return {'restored': 0, 'skipped': 0}
        restored = skipped = 0
        for ident, source, dest, sha, kind, identity in self.conn.execute("SELECT id,source,destination,hash,kind,identity FROM moves WHERE batch=? AND state IN ('moved','planned') ORDER BY id DESC", row).fetchall():
            source, dest = Path(source), Path(dest)
            if source.exists() and not dest.exists():
                self.conn.execute('UPDATE moves SET state=? WHERE id=?', ('undone', ident))
                continue
            try:
                valid = dest.is_dir() and str(dest.stat().st_ino) == identity if kind == 'directory' else dest.is_file() and digest(dest) == sha
                if source.exists() or not valid:
                    skipped += 1
                    continue
                source.parent.mkdir(parents=True, exist_ok=True)
                os.rename(dest, source)
                self.conn.execute('UPDATE moves SET state=? WHERE id=?', ('undone', ident))
                self.conn.commit()
                restored += 1
            except OSError:
                skipped += 1
        self.conn.commit()
        return {'restored': restored, 'skipped': skipped}

    def close(self):
        self.conn.close()


def export_plan(items, filename):
    with open(filename, 'w', encoding='utf-8-sig', newline='') as f:
        keys = list(Decision.__dataclass_fields__)
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(asdict(i) for i in items)
