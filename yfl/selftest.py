import json
import os
import tempfile
import time
import zipfile
from pathlib import Path

from .engine import Store, extract, plan


def run(report):
    results = {}
    with tempfile.TemporaryDirectory(prefix='YFL-test-') as temp:
        root = Path(temp)
        source = root / 'input'
        source.mkdir()
        doc = source / 'Лабораторная.docx'
        with zipfile.ZipFile(doc, 'w') as z:
            z.writestr('word/document.xml', '<document><p>Лабораторная работа</p><p>Выполнил Иванов И.И.</p></document>')
        os.utime(doc, (time.time() - 1200,) * 2)
        items = plan([source], root / 'output', 'Иванов')
        results['content_classification'] = len(items) == 1 and items[0].category == 'Мои работы'
        store = Store(root / 'state')
        try:
            results['move'] = store.move(items)['moved'] == 1
            results['undo'] = store.undo()['restored'] == 1 and doc.exists()
        finally:
            store.close()
        from pypdf import PdfWriter
        pdf = root / 'blank.pdf'
        writer = PdfWriter()
        writer.add_blank_page(width=100, height=100)
        writer.write(str(pdf))
        results['pdf_reader'] = extract(pdf)[1] == 'Нет текстового слоя: нужен OCR'
        rtf = root / 'test.rtf'
        rtf.write_text(r'{\rtf1 hello}', 'ascii')
        results['rtf_reader'] = 'hello' in extract(rtf)[0]
        os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
        from .qtapp import create_app, resource
        app, engine, controller = create_app(root / 'local')
        window = engine.rootObjects()[0]
        window.setVisible(False)
        app.processEvents()
        results['gui_runtime'] = window.title() == 'YFL — YourFileOrganizer'
        results['brand_asset'] = resource('assets/app-icon.png').is_file()
        results['qml_assets'] = resource('qml/Main.qml').is_file()
        results['history_compatible'] = controller.count == 0
        import shiboken6
        shiboken6.delete(engine)
    Path(report).write_text(json.dumps(results, indent=2), 'utf-8')
    if not all(results.values()):
        raise RuntimeError('Self test failed')
