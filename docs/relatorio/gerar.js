const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file://' + __dirname + '/relatorio.html', { waitUntil: 'networkidle' });
  await p.pdf({ path: __dirname + '/Relatorio_Tecnico_A3_CadernetaDigital.pdf', format: 'A4', printBackground: true, preferCSSPageSize: true,
    displayHeaderFooter: true, headerTemplate: '<span></span>',
    footerTemplate: '<div style="width:100%;font-size:8px;color:#6b7a75;padding:0 18mm;display:flex;justify-content:space-between;font-family:Arial"><span>Caderneta Digital da Criança · Relatório Técnico A3</span><span class="pageNumber"></span></div>' });
  await b.close();
})();
