// Native editable .docx generation in the browser. Text stays local; only the
// public docx generator library is fetched when this optional export is used.
importScripts('https://unpkg.com/docx@9.5.1/dist/index.umd.cjs');

const OFFICE = { width: 11906, height: 16838, top: 1440, bottom: 1080, left: 1440, right: 1080 };
const LEGAL = { width: 12240, height: 20160, top: 4032, bottom: 2160, left: 1080, right: 1080 };

self.onmessage = async ({ data }) => {
  try {
    const { text = '', kind = 'other', fontSize = 13 } = data;
    const d = self.docx;
    if (!d) throw new Error('Word export library did not load. Please check your internet connection.');
    const office = kind === 'office';
    const contract = kind === 'contract';
    const page = office ? OFFICE : contract ? LEGAL : OFFICE;
    const children = makeParagraphs(d, text, kind, Number(fontSize));
    const bodyFont = { name: 'Pyidaungsu', size: Number(fontSize) * 2 };
    const footer = new d.Footer({
      children: [new d.Paragraph({
        alignment: d.AlignmentType.CENTER,
        children: [new d.TextRun({ text: '(- ', font: 'Pyidaungsu', size: Number(fontSize) * 2 }), new d.TextRun({ children: [d.PageNumber.CURRENT], font: 'Pyidaungsu', size: Number(fontSize) * 2 }), new d.TextRun({ text: ' -)', font: 'Pyidaungsu', size: Number(fontSize) * 2 })],
      })],
    });
    const document = new d.Document({
      styles: { default: { document: { run: bodyFont } } },
      sections: [{
        properties: {
          page: { size: { width: page.width, height: page.height }, margin: { top: page.top, bottom: page.bottom, left: page.left, right: page.right, header: 720, footer: 720 } },
          titlePage: true,
        },
        footers: { default: footer, first: new d.Footer({ children: [] }) },
        children,
      }],
    });
    const blob = await d.Packer.toBlob(document);
    const buffer = await blob.arrayBuffer();
    self.postMessage({ buffer }, [buffer]);
  } catch (error) {
    self.postMessage({ error: error?.message || String(error) });
  }
};

function makeParagraphs(d, source, kind, fontSize) {
  const lines = source.replace(/\r\n/g, '\n').split('\n');
  const children = [];
  let recipientBlock = false;
  for (const raw of lines) {
    const line = raw.trim();
    if (!line) { children.push(new d.Paragraph({ text: '' })); continue; }
    let alignment = d.AlignmentType.JUSTIFIED;
    let indent = { firstLine: 720 };
    let before = 0;
    if (kind === 'office' && /^သို့\s*[:：]?/.test(line)) {
      alignment = d.AlignmentType.LEFT; indent = undefined; recipientBlock = true;
    } else if (kind === 'office' && isDateLine(line)) {
      alignment = d.AlignmentType.RIGHT; indent = undefined; recipientBlock = false;
    } else if (kind === 'office' && /^အကြောင်းအရာ/.test(line)) {
      indent = undefined; before = 120; recipientBlock = false;
    } else if (kind === 'office' && recipientBlock) {
      alignment = d.AlignmentType.LEFT; indent = { left: 720 };
    } else if (kind === 'contract') {
      indent = { firstLine: 360 };
    }
    children.push(new d.Paragraph({
      alignment,
      indent,
      spacing: { after: 100, before },
      children: [new d.TextRun({ text: line, font: 'Pyidaungsu', size: fontSize * 2 })],
    }));
  }
  return children.length ? children : [new d.Paragraph('')];
}

function isDateLine(line) {
  return /(ရက်စွဲ|နေ့စွဲ|date|\d{1,2}[\/.\-]\d{1,2}[\/.\-]\d{2,4}|ခုနှစ်)/i.test(line);
}
