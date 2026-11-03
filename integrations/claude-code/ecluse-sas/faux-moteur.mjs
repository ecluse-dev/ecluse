// Faux moteur Écluse, pour tester le mod ecluse-sas sans le moteur Dart.
// Masque seulement : emails, NIR (15 chiffres) et "Prénom Nom" listés ci-dessous.
// Lancer : node faux-moteur.mjs        (écoute sur 127.0.0.1:8787)
// Ce n'est PAS une protection réelle : uniquement pour vérifier la tuyauterie.
import http from 'node:http'

const NOMS = ['Jean Dupont', 'Marie Martin']
const tables = new Map() // session -> Map(token -> valeur)

function redact(session, text) {
  const table = tables.get(session) ?? new Map()
  tables.set(session, table)
  const inverse = new Map([...table].map(([t, v]) => [v, t]))
  let n = 0
  const swap = (kind) => (valeur) => {
    n++
    if (!inverse.has(valeur)) {
      const token = `[${kind}_${[...table.keys()].filter((k) => k.startsWith(`[${kind}_`)).length + 1}]`
      table.set(token, valeur)
      inverse.set(valeur, token)
    }
    return inverse.get(valeur)
  }
  for (const nom of NOMS) if (text.includes(nom)) text = text.split(nom).join(swap('NOM')(nom))
  text = text.replace(/[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g, swap('EMAIL'))
  text = text.replace(/\b[12](?:\s?\d){14}\b/g, swap('NIR'))
  return { text, entities: n }
}

function restore(session, text) {
  const table = tables.get(session) ?? new Map()
  return { text: text.replace(/\[[A-Z_]+_\d+\]/g, (t) => table.get(t) ?? t) }
}

http.createServer((req, res) => {
  let body = ''
  req.on('data', (c) => (body += c))
  req.on('end', () => {
    try {
      const { session, text } = JSON.parse(body)
      const out = req.url === '/v1/redact' ? redact(session, text)
        : req.url === '/v1/restore' ? restore(session, text) : null
      if (!out) { res.writeHead(404).end(); return }
      console.log(req.url, '\n  reçu   :', text, '\n  renvoyé:', out.text)
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(out))
    } catch (err) {
      res.writeHead(400).end(String(err))
    }
  })
}).listen(8787, '127.0.0.1', () => console.log('Faux moteur Écluse sur http://127.0.0.1:8787'))
