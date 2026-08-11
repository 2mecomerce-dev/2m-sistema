// Proxy server-side para o relatório de Lucro por Pedido da Upseller.
//
// Existe porque essa API da Upseller nao e publica/documentada: autentica
// por cookie de sessao (HttpOnly, so o navegador consegue reenviar) e o
// CORS dela so aceita chamadas vindas do proprio dominio da Upseller. Essa
// function roda no servidor (sem CORS, sem depender do navegador do
// usuario) e guarda o cookie como variavel de ambiente no Vercel — nunca
// no codigo, nunca exposto pro navegador de quem usa o sistema.
//
// O cookie de sessao expira (provavelmente em horas/dias). Quando parar de
// funcionar, e so capturar um novo pelo DevTools (Network > profit-report)
// e atualizar a variavel UPSELLER_COOKIE no Vercel.

module.exports = async (req, res) => {
  const { platform, beginDate, endDate } = req.query;
  if (!platform || !beginDate || !endDate) {
    res.status(400).json({ error: 'Parâmetros obrigatórios: platform, beginDate, endDate' });
    return;
  }

  const cookie = process.env.UPSELLER_COOKIE;
  const deviceId = process.env.UPSELLER_DEVICE_ID;
  if (!cookie || !deviceId) {
    res.status(500).json({ error: 'UPSELLER_COOKIE / UPSELLER_DEVICE_ID não configurados no servidor (Vercel > Settings > Environment Variables)' });
    return;
  }

  const url = `https://app.upseller.com/api/profit-report/page?tabValue=1&platform=${encodeURIComponent(platform)}&beginDate=${encodeURIComponent(beginDate)}&endDate=${encodeURIComponent(endDate)}&searchDateType=1&pageSize=50&pageNum=1&sortName=0&sortValue=0`;

  try {
    const upstream = await fetch(url, {
      headers: {
        cookie,
        deviceid: deviceId,
        referer: `https://app.upseller.com/pt/finance/profit-report/order/${platform}`,
        accept: 'application/json, text/plain, */*',
        'accept-language': 'pt-BR,pt;q=0.9',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
      },
    });
    const text = await upstream.text();
    res.status(upstream.status).setHeader('content-type', 'application/json; charset=utf-8').send(text);
  } catch (e) {
    res.status(502).json({ error: 'Falha ao consultar a Upseller: ' + e.message });
  }
};
