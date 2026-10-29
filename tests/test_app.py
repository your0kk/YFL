import os
import tempfile
import time
import unittest
from pathlib import Path

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication
import shiboken6

QQuickStyle.setStyle('Basic')
APP = QApplication.instance() or QApplication([])

from yfl.qtapp import Controller, create_app


class AppTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.controller = Controller(self.root / 'state')
        self.source = self.root / 'input'
        self.source.mkdir()
        self.output = self.root / 'output'
        self.controller._source = str(self.source)
        self.controller._output = str(self.output)
        self.controller._author = 'Иванов'

    def tearDown(self):
        self.controller.deleteLater()
        APP.processEvents()
        self.temp.cleanup()

    def fixture(self, name='Лабораторная.txt'):
        p = self.source / name
        p.write_text('Лабораторная работа №2. Выполнил Иванов И.И.', 'utf-8')
        os.utime(p, (time.time() - 1200,) * 2)
        return p

    def wait(self):
        deadline = time.monotonic() + 8
        while self.controller.busy and time.monotonic() < deadline:
            QTest.qWait(10)
        self.assertFalse(self.controller.busy)

    def scan(self):
        self.controller.scan()
        self.wait()

    def test_async_scan_move_and_undo(self):
        source = self.fixture()
        self.scan()
        self.assertTrue(self.controller.analyzed)
        self.assertEqual(self.controller.count, 1)
        self.assertEqual(self.controller.detail['section'], 'Мои работы')
        destination = Path(self.controller.detail['destination'])
        self.controller.apply()
        self.wait()
        self.assertFalse(source.exists())
        self.assertTrue(destination.exists())
        self.controller.loadHistory()
        self.assertEqual(self.controller.history[0]['status'], 'Перемещён')
        self.controller.undo()
        self.wait()
        self.assertTrue(source.exists())
        self.assertFalse(destination.exists())

    def test_setting_change_invalidates_plan(self):
        self.fixture()
        self.scan()
        self.controller.setAuthor('Петров')
        self.assertFalse(self.controller.analyzed)
        self.assertEqual(self.controller.count, 0)

    def test_deselected_file_stays_put(self):
        p = self.fixture()
        self.scan()
        self.controller.toggle(0)
        self.assertEqual(self.controller.selectedCount, 0)
        self.controller.apply()
        self.assertTrue(p.exists())
        self.assertFalse(self.controller.busy)

    def test_search_filter_model(self):
        self.fixture()
        self.fixture('Практическая.txt')
        self.scan()
        self.controller.search('Практическая')
        self.assertEqual(self.controller.model.rowCount(), 1)
        self.controller.search('нет такого файла')
        self.assertEqual(self.controller.shownCount, 0)

    def test_model_checkbox_updates(self):
        self.fixture()
        self.scan()
        role = [key for key, value in self.controller.model.roleNames().items() if value == b'isChecked'][0]
        index = self.controller.model.index(0)
        self.assertTrue(self.controller.model.data(index, role))
        self.controller.toggle(0)
        self.assertFalse(self.controller.model.data(index, role))

    def test_manual_category(self):
        self.fixture()
        self.scan()
        self.controller.changeCategory('Методички и задания')
        self.assertEqual(self.controller.detail['section'], 'Методички и задания')
        self.assertIn('Методички и задания', self.controller.detail['destination'])

    def test_settings_persist(self):
        self.controller.setAuthor('Петров')
        self.controller.setAnimations(False)
        second = Controller(self.root / 'state')
        self.assertEqual(second.author, 'Петров')
        self.assertFalse(second.animations)
        second.deleteLater()

    def test_cannot_apply_unanalyzed_plan(self):
        self.fixture()
        self.controller.apply()
        self.assertFalse(self.controller.busy)
        self.assertTrue((self.source / 'Лабораторная.txt').exists())

    def test_cancelled_scan_cannot_be_applied(self):
        self.controller.cancel_event.set()
        self.controller._finished('analyzing', [])
        self.assertFalse(self.controller.analyzed)

    def test_qml_load_and_navigation(self):
        app, engine, controller = create_app(self.root / 'qmlstate')
        window = engine.rootObjects()[0]
        window.setWidth(1180)
        window.setHeight(760)
        window.setVisible(False)
        app.processEvents()
        self.assertEqual(window.title(), 'YFL — YourFileOrganizer')
        for page in ['rules', 'history', 'settings', 'files']:
            window.setProperty('page', page)
            app.processEvents()
            self.assertEqual(window.property('page'), page)
        self.assertTrue(controller.logo.isLocalFile())
        shiboken6.delete(engine)
        controller.deleteLater()


if __name__ == '__main__':
    unittest.main()
