import os
import tempfile
import time
import unittest
import zipfile
from pathlib import Path

from yfl.engine import Store, candidates, classify, extract, plan


class ClassificationTests(unittest.TestCase):
    def classify(self, name, text='', author='Иванов'):
        return classify(Path(name), text, author, '')

    def test_own_laboratory(self):
        r = self.classify('Лабораторная 2.docx', 'Лабораторная работа № 2. Выполнил студент Иванов И.И.')
        self.assertEqual(r[:2], ('Мои работы', 'Лабораторные'))

    def test_methodology_is_not_own_work(self):
        self.assertEqual(self.classify('Методические указания Иванов.pdf', 'Методические указания к лабораторной работе')[0], 'Методички и задания')

    def test_unknown_not_assumed_completed(self):
        self.assertEqual(self.classify('Лабораторная.docx', 'Лабораторная работа. Выполнил студент __________')[0], 'Требуют проверки')

    def test_coursework_from_content(self):
        self.assertEqual(self.classify('document.docx', 'Курсовая работа. Выполнил Иванов И.И.')[:2], ('Мои работы', 'Курсовые'))

    def test_no_author_means_no_own_work(self):
        self.assertNotEqual(self.classify('Иванов.docx', 'текст', '')[0], 'Мои работы')

    def test_bibliography_does_not_set_author(self):
        self.assertNotEqual(self.classify('document.docx', 'Введение ' * 1000 + ' Иванов И.И.')[0], 'Мои работы')

    def test_teacher_assignment(self):
        self.assertEqual(self.classify('Лабораторная 1.pdf', 'Лабораторная работа. Цель занятия. Порядок выполнения. Контрольные вопросы.')[0], 'Методички и задания')

    def test_other_author(self):
        self.assertEqual(self.classify('report.docx', 'Курсовая работа. Выполнил Петров П.П.')[0], 'Работы других авторов')

    def test_teacher_signature_not_student(self):
        self.assertNotEqual(self.classify('report.docx', 'Выполнил: ______ Проверил Петров П.П.')[0], 'Работы других авторов')

    def test_execution_word_not_author(self):
        self.assertNotEqual(self.classify('report.docx', 'Выполнение работ по профессии. Руководитель Петров П.П.')[0], 'Работы других авторов')

    def test_runtime_text_skipped(self):
        self.assertEqual(self.classify('COPYRIGHT.txt', 'Copyright 2026')[0], '')


class FileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / 'input'
        self.output = self.root / 'output'
        self.source.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def file(self, name, text='Лабораторная работа. Выполнил Иванов И.И.'):
        p = self.source / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, 'utf-8')
        os.utime(p, (time.time() - 1200,) * 2)
        return p

    def test_move_and_undo(self):
        p = self.file('Лаба.txt')
        items = plan([self.source], self.output, 'Иванов')
        store = Store(self.root / 'state')
        try:
            self.assertEqual(store.move(items)['moved'], 1)
            self.assertFalse(p.exists())
            self.assertEqual(store.undo()['restored'], 1)
            self.assertTrue(p.exists())
        finally:
            store.close()

    def test_changed_file_is_not_moved(self):
        p = self.file('Лаба.txt')
        items = plan([self.source], self.output, 'Иванов')
        p.write_text('Изменён', 'utf-8')
        store = Store(self.root / 'state')
        try:
            self.assertEqual(store.move(items)['skipped'], 1)
            self.assertTrue(p.exists())
        finally:
            store.close()

    def test_undo_preserves_edited_destination(self):
        self.file('Лаба.txt')
        items = plan([self.source], self.output, 'Иванов')
        store = Store(self.root / 'state')
        try:
            store.move(items)
            Path(items[0].destination).write_text('Изменён', 'utf-8')
            self.assertEqual(store.undo()['skipped'], 1)
            self.assertTrue(Path(items[0].destination).exists())
        finally:
            store.close()

    def test_collision_is_renamed_in_plan(self):
        self.file('one/Лаба.txt')
        self.file('two/Лаба.txt')
        items = plan([self.source], self.output, 'Иванов')
        self.assertEqual(len({i.destination for i in items}), 2)

    def test_never_overwrite(self):
        p = self.file('Лаба.txt')
        items = plan([self.source], self.output, 'Иванов')
        d = Path(items[0].destination)
        d.parent.mkdir(parents=True)
        d.write_text('Занято', 'utf-8')
        store = Store(self.root / 'state')
        try:
            self.assertEqual(store.move(items)['moved'], 0)
            self.assertEqual(d.read_text('utf-8'), 'Занято')
            self.assertTrue(p.exists())
        finally:
            store.close()

    def test_project_files_are_skipped(self):
        self.file('project/package.json', '{}')
        self.file('project/Лаба.txt')
        self.assertEqual(list(candidates([self.source], self.output)), [])

    def test_docx_content(self):
        p = self.source / 'file.docx'
        with zipfile.ZipFile(p, 'w') as z:
            z.writestr('word/document.xml', '<document><p>Лабораторная работа</p><p>Иванов И.И.</p></document>')
        text, status = extract(p)
        self.assertIn('Иванов', text)

    def test_folder_move_and_undo_preserve_contents(self):
        p = self.file('project/example.txt', 'content')
        folder = p.parent
        target = self.root / 'folders' / 'project'
        store = Store(self.root / 'state')
        try:
            self.assertEqual(len(store.move_paths([(folder, target)])), 1)
            self.assertTrue((target / p.name).is_file())
            self.assertEqual(store.undo()['restored'], 1)
            self.assertTrue(p.is_file())
        finally:
            store.close()

    def test_recent_files_are_skipped(self):
        p = self.file('recent.txt')
        os.utime(p, None)
        self.assertEqual(list(candidates([self.source], self.output)), [])

    def test_source_equals_output_rejected(self):
        with self.assertRaises(ValueError):
            plan([self.source], self.source, 'Иванов')


if __name__ == '__main__':
    unittest.main()
