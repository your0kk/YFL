from __future__ import annotations

import json
import os
import sys
import threading
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QAbstractListModel, QModelIndex, QObject, Property, QTimer, Qt, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QFont, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication, QFileDialog

from .engine import Decision, Store, candidates, export_plan, plan, state_dir


def resource(name):
    return Path(getattr(sys, '_MEIPASS', Path(__file__).resolve().parent.parent)) / name


def human_size(size):
    if size >= 1024 ** 3:
        return f'{size / 1024 ** 3:.1f} ГБ'
    if size >= 1024 ** 2:
        return f'{size / 1024 ** 2:.1f} МБ'
    return f'{max(1, round(size / 1024))} КБ'


def present(item, index):
    path = Path(item.source)
    ext = path.suffix.lstrip('.').upper()
    palette = {'PDF': '#f15e62', 'DOCX': '#499afa', 'DOC': '#499afa', 'XLSX': '#4ec794', 'XLS': '#4ec794', 'CSV': '#4ec794', 'PPTX': '#f58a5c', 'PPT': '#f58a5c'}
    label = {'DOCX': 'Word', 'DOC': 'Word', 'XLSX': 'Excel', 'XLS': 'Excel', 'PPTX': 'PowerPoint', 'PPT': 'PowerPoint', 'TXT': 'Текст', 'MD': 'Текст'}
    dest = Path(item.destination) if item.destination else None
    relative = str(Path(item.category) / item.kind) if item.category else 'После проверки'
    folder_name = {'Downloads': 'Загрузки', 'Desktop': 'Рабочий стол', 'Documents': 'Документы'}.get(path.parent.name, path.parent.name)
    destination_label = ' / '.join(dest.parent.parts[-3:]) if dest else relative
    return {'itemId': index, 'fileName': path.name, 'fileType': label.get(ext, ext), 'extension': ext, 'fileSize': human_size(item.size), 'fileColor': palette.get(ext, '#a4afc2'), 'isChecked': item.selected, 'section': item.category, 'workType': item.kind, 'destination': str(dest) if dest else '', 'destinationLabel': destination_label, 'sourcePath': str(path), 'sourceFolder': str(path.parent), 'sourceFolderLabel': folder_name, 'reason': item.reason, 'readStatus': item.read_status, 'fileStatus': item.status, 'author': item.author, 'needsReview': item.category == 'Требуют проверки'}


class FileModel(QAbstractListModel):
    fields = list(present(Decision('', '', '', '', '', '', '', 0, 0), 0))

    def __init__(self, controller):
        super().__init__(controller)
        self.controller = controller
        self.visible = []

    def roleNames(self):
        return {int(Qt.ItemDataRole.UserRole) + i + 1: key.encode() for i, key in enumerate(self.fields)}

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self.visible)

    def data(self, index, role):
        key = role - int(Qt.ItemDataRole.UserRole) - 1
        if not index.isValid() or not 0 <= key < len(self.fields):
            return None
        item_id = self.visible[index.row()]
        return present(self.controller.items[item_id], item_id).get(self.fields[key])

    def refresh(self):
        query = self.controller.query.casefold()
        kind = self.controller.type_filter
        self.beginResetModel()
        self.visible = [n for n, i in enumerate(self.controller.items) if (not query or query in (Path(i.source).name + ' ' + i.category + ' ' + i.kind).casefold()) and (kind == 'Все типы' or present(i, n)['fileType'] == kind or kind == 'Нужна проверка' and i.category == 'Требуют проверки')]
        self.endResetModel()

    def update_item(self, item_id):
        if item_id in self.visible:
            row = self.visible.index(item_id)
            self.dataChanged.emit(self.index(row), self.index(row))


class Controller(QObject):
    changed = Signal()
    settingsChanged = Signal()
    progressSignal = Signal(str)
    resultSignal = Signal(str, object)
    notice = Signal(str, str)

    def __init__(self, settings_folder=None):
        super().__init__()
        self.folder = Path(settings_folder) if settings_folder else state_dir()
        self.folder.mkdir(parents=True, exist_ok=True)
        self.settings_file = self.folder / 'settings.json'
        try:
            settings = json.loads(self.settings_file.read_text('utf-8-sig'))
        except (OSError, ValueError):
            settings = {}
        self._source = settings.get('source', str(Path.home() / 'Downloads'))
        self._output = settings.get('output', str(Path.home() / 'Documents' / 'Учёба'))
        self._author = settings.get('author', '')
        self._recursive = bool(settings.get('recursive', True))
        self._animations = bool(settings.get('animations', True))
        self._include_desktop = bool(settings.get('desktop', False))
        self.items = []
        self.query = ''
        self.type_filter = 'Все типы'
        self._busy = False
        self._analyzed = False
        self._selected = -1
        self._status = 'Выберите папку. Перемещения начнутся только после подтверждения.'
        self._stage = 'idle'
        self._history = []
        self._custom_folders = settings.get('folders', [])
        self.cancel_event = threading.Event()
        self.model = FileModel(self)
        self.progressSignal.connect(self._progress)
        self.resultSignal.connect(self._finished)

    files = Property(QObject, lambda self: self.model, constant=True)
    source = Property(str, lambda self: self._source, notify=settingsChanged)
    output = Property(str, lambda self: self._output, notify=settingsChanged)
    author = Property(str, lambda self: self._author, notify=settingsChanged)
    recursive = Property(bool, lambda self: self._recursive, notify=settingsChanged)
    animations = Property(bool, lambda self: self._animations, notify=settingsChanged)
    includeDesktop = Property(bool, lambda self: self._include_desktop, notify=settingsChanged)
    busy = Property(bool, lambda self: self._busy, notify=changed)
    analyzed = Property(bool, lambda self: self._analyzed, notify=changed)
    status = Property(str, lambda self: self._status, notify=changed)
    stage = Property(str, lambda self: self._stage, notify=changed)
    count = Property(int, lambda self: len(self.items), notify=changed)
    shownCount = Property(int, lambda self: self.model.rowCount(), notify=changed)
    selectedCount = Property(int, lambda self: sum(i.selected and i.status == 'Готов к переносу' for i in self.items), notify=changed)
    selectedSize = Property(str, lambda self: human_size(sum(i.size for i in self.items if i.selected and i.status == 'Готов к переносу')), notify=changed)
    selectedId = Property(int, lambda self: self._selected, notify=changed)
    detail = Property('QVariantMap', lambda self: present(self.items[self._selected], self._selected) if 0 <= self._selected < len(self.items) else {}, notify=changed)
    history = Property('QVariantList', lambda self: self._history, notify=changed)
    logo = Property(QUrl, lambda self: QUrl.fromLocalFile(str(resource('assets/app-icon.png'))), constant=True)
    sourceName = Property(str, lambda self: {'Downloads': 'Загрузки', 'Desktop': 'Рабочий стол', 'Documents': 'Документы'}.get(Path(self._source).name, Path(self._source).name), notify=settingsChanged)
    customFolders = Property('QVariantList', lambda self: [{'label': Path(p).name, 'path': p} for p in self._custom_folders if Path(p).is_dir()], notify=settingsChanged)

    def save(self):
        temp = self.settings_file.with_suffix('.tmp')
        temp.write_text(json.dumps({'source': self._source, 'output': self._output, 'author': self._author, 'recursive': self._recursive, 'animations': self._animations, 'desktop': self._include_desktop, 'folders': self._custom_folders}, ensure_ascii=False, indent=2), 'utf-8')
        os.replace(temp, self.settings_file)

    def _invalidate(self):
        self.items = []
        self._analyzed = False
        self._selected = -1
        self._stage = 'idle'
        self.model.refresh()
        self.save()
        self.settingsChanged.emit()
        self.changed.emit()

    @Slot(str)
    def setAuthor(self, value):
        if not self._busy and value.strip() != self._author:
            self._author = value.strip()
            self._invalidate()

    @Slot(bool)
    def setRecursive(self, value):
        if not self._busy and value != self._recursive:
            self._recursive = value
            self._invalidate()

    @Slot(bool)
    def setDesktop(self, value):
        if not self._busy and value != self._include_desktop:
            self._include_desktop = value
            self._invalidate()

    @Slot(bool)
    def setAnimations(self, value):
        self._animations = value
        self.save()
        self.settingsChanged.emit()

    @Slot(str)
    def setSource(self, value):
        if self._busy:
            return
        folder = Path(value).expanduser()
        if not folder.is_dir():
            self.notice.emit('Папка недоступна', 'Выберите существующую папку с файлами.')
            return
        self._source = str(folder.resolve())
        self._invalidate()
        self._status = 'Папка выбрана. Нажмите «Проверить файлы», чтобы составить план.'
        self.changed.emit()

    @Slot(str)
    def quickFolder(self, name):
        if name == 'study':
            folder = Path(self._output)
        else:
            folder = Path.home() / name
        if name == 'study':
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(folder)))
        else:
            self.setSource(str(folder))

    @Slot()
    def chooseSource(self):
        if not self._busy:
            path = QFileDialog.getExistingDirectory(None, 'Папка с файлами', self._source)
            if path:
                self.setSource(path)

    @Slot()
    def addFolder(self):
        if self._busy:
            return
        path = QFileDialog.getExistingDirectory(None, 'Добавить папку', self._source)
        if path:
            if path not in self._custom_folders:
                self._custom_folders.append(path)
            self.setSource(path)

    @Slot()
    def chooseOutput(self):
        if self._busy:
            return
        path = QFileDialog.getExistingDirectory(None, 'Куда складывать файлы', self._output)
        if path:
            self._output = path
            self._invalidate()

    @Slot(str)
    def search(self, text):
        self.query = text
        self.model.refresh()
        self.changed.emit()

    @Slot(str)
    def filterType(self, value):
        self.type_filter = value
        self.model.refresh()
        self.changed.emit()

    @Slot(int)
    def select(self, index):
        if 0 <= index < len(self.items):
            self._selected = index
            self.changed.emit()

    @Slot(int)
    def toggle(self, index):
        if self._busy or not 0 <= index < len(self.items):
            return
        item = self.items[index]
        if item.status != 'Готов к переносу':
            return
        item.selected = not item.selected
        self._selected = index
        self.model.update_item(index)
        self.changed.emit()

    @Slot()
    def toggleAll(self):
        if self._busy:
            return
        visible = [i for i in self.model.visible if self.items[i].status == 'Готов к переносу']
        value = not all(self.items[i].selected for i in visible)
        for index in visible:
            self.items[index].selected = value
            self.model.update_item(index)
        self.changed.emit()

    def _run(self, operation, action):
        if self._busy:
            return
        self.cancel_event.clear()
        self._busy = True
        self._stage = action
        self.changed.emit()
        def worker():
            try:
                self.resultSignal.emit(action, operation())
            except Exception as e:
                self.resultSignal.emit('error', str(e))
        threading.Thread(target=worker, daemon=True).start()

    def _report(self, n, name):
        self.progressSignal.emit(f'Проверяю файл {n}: {name}')

    @Slot(str)
    def _progress(self, text):
        self._status = text
        self.changed.emit()

    @Slot(str, object)
    def _finished(self, action, data):
        self._busy = False
        stopped = self.cancel_event.is_set()
        if action == 'analyzing':
            self.items = data
            self._analyzed = not stopped
            self._selected = 0 if data else -1
            self._stage = 'preview' if data else 'empty'
            self._status = f'Проверено {len(data)} файлов. Выберите файлы для перемещения.' if data else 'Подходящих документов нет. Проверьте подпапки или выберите другую папку.'
            if stopped:
                self._stage = 'idle'
                self._status = 'Проверка остановлена. Частичный список показан; для переноса повторите проверку.'
        elif action == 'moving':
            self._stage = 'done'
            self._status = f'Перемещено: {data["moved"]}. Пропущено: {data["skipped"]}. Ошибок: {len(data["errors"])}.'
            self.notice.emit('Сортировка завершена' if not stopped else 'Сортировка остановлена', self._status)
            if data['errors']:
                self._status += ' ' + data['errors'][0]['error']
            self._analyzed = False
        elif action == 'undoing':
            self.items = []
            self._selected = -1
            self._analyzed = False
            self._stage = 'idle'
            self._status = f'Возвращено: {data["restored"]}. Пропущено: {data["skipped"]}.'
            self.notice.emit('Возврат завершён', self._status)
            self.loadHistory()
        else:
            self._stage = 'error'
            self._analyzed = False
            self._status = str(data)
            self.notice.emit('Не удалось завершить', str(data))
        self.model.refresh()
        self.changed.emit()

    @Slot()
    def scan(self):
        if self._busy:
            return
        source, output = Path(self._source), Path(self._output)
        if not source.is_dir() or source.resolve() == Path(source.anchor) or source.name.casefold() in {'windows', 'program files', 'appdata'}:
            self.notice.emit('Выберите личную папку', 'Подойдут Загрузки, рабочий стол или папка с учебными документами.')
            return
        if source.resolve() == output.resolve():
            self.notice.emit('Папки совпадают', 'Выберите другую папку назначения. Уже разобранные файлы можно открыть через «Результат».')
            return
        self.items = []
        self._analyzed = False
        self._selected = -1
        self.model.refresh()
        self.save()
        roots = [source]
        if self._include_desktop:
            roots.append(Path.home() / 'Desktop')
        author, recursive = self._author, self._recursive
        self._status = 'Читаю содержимое документов…'
        self._run(lambda: plan(roots, output, author, recursive, self._report, self.cancel_event), 'analyzing')

    @Slot()
    def apply(self):
        if self._busy or not self._analyzed:
            return
        selected = [i for i in self.items if i.selected and i.status == 'Готов к переносу']
        if not selected:
            return
        def operation():
            store = Store(self.folder)
            try:
                return store.move(selected, self._report, self.cancel_event)
            finally:
                store.close()
        self._status = 'Перемещаю выбранные файлы…'
        self._run(operation, 'moving')

    @Slot()
    def cancel(self):
        if self._busy:
            self.cancel_event.set()
            self._status = 'Останавливаю после текущего файла…'
            self.changed.emit()

    @Slot()
    def undo(self):
        if self._busy:
            return
        def operation():
            store = Store(self.folder)
            try:
                return store.undo()
            finally:
                store.close()
        self._run(operation, 'undoing')

    @Slot()
    def loadHistory(self):
        store = Store(self.folder)
        try:
            rows = store.conn.execute('SELECT source,destination,state,created,batch FROM moves ORDER BY id DESC LIMIT 1000').fetchall()
        finally:
            store.close()
        labels = {'moved': 'Перемещён', 'undone': 'Возвращён', 'planned': 'Требует проверки', 'repacked': 'В составе проекта'}
        self._history = [{'name': Path(a).name, 'source': a, 'destination': b, 'status': labels.get(c, c), 'date': datetime.fromtimestamp(d).strftime('%d.%m.%Y · %H:%M'), 'batch': e} for a, b, c, d, e in rows]
        self.changed.emit()

    @Slot(str)
    def changeCategory(self, category):
        if self._busy or not 0 <= self._selected < len(self.items):
            return
        if category not in ['Мои работы', 'Методички и задания', 'Работы других авторов', 'Требуют проверки']:
            return
        item = self.items[self._selected]
        if item.status != 'Готов к переносу':
            return
        target = Path(self._output) / category / item.kind / Path(item.source).name
        other = {i.destination.casefold() for n, i in enumerate(self.items) if n != self._selected}
        n = 2
        while target.exists() or str(target).casefold() in other:
            p = Path(item.source)
            target = target.parent / (p.stem + f' ({n})' + p.suffix)
            n += 1
        item.destination = str(target)
        item.category = category
        item.reason = 'Раздел выбран вами'
        self.model.update_item(self._selected)
        self.changed.emit()

    @Slot()
    def changeDestination(self):
        if self._busy or not 0 <= self._selected < len(self.items):
            return
        item = self.items[self._selected]
        if item.status != 'Готов к переносу':
            return
        path = QFileDialog.getExistingDirectory(None, 'Куда переместить этот файл', str(Path(item.destination).parent))
        if path:
            if Path(path).resolve() == Path(item.source).parent.resolve():
                self.notice.emit('Файл уже здесь', 'Снимите выбор с файла, чтобы оставить его на месте.')
                return
            dest = Path(path) / Path(item.source).name
            others = {i.destination.casefold() for n, i in enumerate(self.items) if n != self._selected}
            n = 2
            while dest.exists() or str(dest).casefold() in others:
                p = Path(item.source)
                dest = Path(path) / (p.stem + f' ({n})' + p.suffix)
                n += 1
            item.destination = str(dest)
            item.reason = 'Папка выбрана вами'
            self.model.update_item(self._selected)
            self.changed.emit()

    @Slot()
    def openResult(self):
        path = Path(self._output)
        if path.is_dir():
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(path)))
        else:
            self.notice.emit('Здесь появятся файлы', 'Папка будет создана при первом перемещении.')

    @Slot()
    def revealSelected(self):
        if 0 <= self._selected < len(self.items):
            item = self.items[self._selected]
            path = Path(item.destination) if item.status == 'Перемещён' else Path(item.source)
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(path.parent)))

    @Slot()
    def exportList(self):
        if not self.items or self._busy:
            return
        filename, _ = QFileDialog.getSaveFileName(None, 'Сохранить план', 'YFL-план.csv', 'CSV (*.csv)')
        if filename:
            export_plan(self.items, filename)
            self.notice.emit('Список сохранён', filename)


def create_app(settings_folder=None):
    app = QApplication.instance()
    if app is None:
        QApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
        QQuickStyle.setStyle('Basic')
        app = QApplication(sys.argv)
        app.setApplicationName('YFL — YourFileOrganizer')
        app.setOrganizationName('YFL')
        app.setFont(QFont('Segoe UI', 10))
        app.setWindowIcon(QIcon(str(resource('assets/yfl.ico'))))
    controller = Controller(settings_folder)
    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda errors: print('\n'.join(e.toString() for e in errors), file=sys.stderr, flush=True))
    engine.rootContext().setContextProperty('backend', controller)
    engine.load(QUrl.fromLocalFile(str(resource('qml/Main.qml'))))
    if not engine.rootObjects():
        raise RuntimeError('Не удалось загрузить интерфейс YFL')
    return app, engine, controller


def main():
    app, engine, controller = create_app()
    result = app.exec()
    import shiboken6
    shiboken6.delete(engine)
    sys.exit(result)
