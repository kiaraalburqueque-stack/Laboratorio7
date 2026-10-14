"""Produce un informe Word sencillo desde el informe Markdown sin dependencias."""
from pathlib import Path
from xml.sax.saxutils import escape
from zipfile import ZipFile, ZIP_DEFLATED
import re

ROOT = Path(__file__).resolve().parent.parent
source = ROOT / 'docs' / 'Informe-Laboratorio07.md'


def paragraph(text, style='Normal'):
    text = text.replace('**', '').replace('`', '').strip()
    return (f'<w:p><w:pPr><w:pStyle w:val="{style}"/></w:pPr>'
            f'<w:r><w:t xml:space="preserve">{escape(text)}</w:t></w:r></w:p>')


parts = []
table_rows = []


def flush_table():
    if not table_rows:
        return
    table = ['<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders>']
    for side in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        table.append(f'<w:{side} w:val="single" w:sz="4" w:color="D9E1F2"/>')
    table.append('</w:tblBorders></w:tblPr>')
    for index, row in enumerate(table_rows):
        table.append('<w:tr>')
        for cell in row:
            shading = '<w:shd w:fill="EAF0FF"/>' if index == 0 else ''
            table.append('<w:tc><w:tcPr><w:tcW w:w="1800" w:type="dxa"/>'
                         + shading + '</w:tcPr>' + paragraph(cell) + '</w:tc>')
        table.append('</w:tr>')
    table.append('</w:tbl>')
    parts.append(''.join(table))
    table_rows.clear()


for line in source.read_text(encoding='utf-8').splitlines():
    if line.startswith('|'):
        cells = [cell.strip() for cell in line.strip('|').split('|')]
        if not all(re.fullmatch(r'[-: ]+', cell) for cell in cells):
            table_rows.append(cells)
        continue
    flush_table()
    if not line.strip():
        continue
    if line.startswith('# '):
        parts.append(paragraph(line[2:], 'Title'))
    elif line.startswith('## '):
        parts.append(paragraph(line[3:], 'Heading1'))
    else:
        parts.append(paragraph(line))
flush_table()

document = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            '<w:body>' + ''.join(parts)
            + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr></w:body></w:document>')
styles = '''<?xml version="1.0" encoding="UTF-8"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/><w:lang w:val="es-PE"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="280"/></w:pPr><w:rPr><w:b/><w:color w:val="2246A0"/><w:sz w:val="36"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="140"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:color w:val="2246A0"/><w:sz w:val="26"/></w:rPr></w:style>
</w:styles>'''
content_types = '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>'''
relationships = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'''
document_relationships = '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>'''
output = ROOT / 'docs' / 'Informe-Laboratorio07.docx'
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for name, content in [('[Content_Types].xml', content_types), ('_rels/.rels', relationships),
                          ('word/document.xml', document), ('word/styles.xml', styles),
                          ('word/_rels/document.xml.rels', document_relationships)]:
        archive.writestr(name, content.encode('utf-8'))
print(f'Informe generado: {output.name}')
