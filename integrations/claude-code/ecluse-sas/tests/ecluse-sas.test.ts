import { expect, test } from 'claude-code/testing'

const ORIGINAL = 'Résume le dossier de Jean Dupont, NIR 1 84 12 75 123 456 78'
const MASKED = 'Résume le dossier de [NOM_1], NIR [NIR_1]'

// Stubs communs : ce que Claude Code répondrait à la place du moteur.
function engine(on, fetch) {
  on('session.id', () => ({ value: 'sess-test' }))
  on('ui.status', () => ({ value: undefined }))
  on('ui.log', () => ({ value: undefined }))
  on('http.fetch', fetch)
  // Ce qui arrive au bout de la chaîne : on renvoie le texte reçu, pour vérifier
  // ce qui serait parti vers Claude.
  on('prompt.submit', ($, e) => ({ text: e.text }))
}

const ok = (body) => ({ value: { status: 200, ok: true, headers: {}, text: JSON.stringify(body) } })

test('moteur OK : le prompt part pseudonymisé', async ($, on) => {
  const seen: string[] = []
  engine(on, ($, e) => {
    seen.push(e.url)
    return ok({ text: MASKED, entities: 2 })
  })
  const out = await $.prompt.submit({ text: ORIGINAL })
  expect(out.text).toBe(MASKED)
  expect(seen).toEqual(['http://127.0.0.1:8787/v1/redact'])
})

test('moteur injoignable : le prompt est bloqué', async ($, on) => {
  engine(on, () => ({ deny: 'connect ECONNREFUSED 127.0.0.1:8787' }))
  const out = await $.prompt.submit({ text: ORIGINAL })
  expect(out.drop).toMatch(/n'a PAS été envoyé/)
  expect(out.text).toBeUndefined()
})

test('moteur trop lent (fetch coupé à 30 s) : le prompt est bloqué', async ($, on) => {
  // Le temps passé dans $.http.fetch ne compte pas dans le budget de 10 s du hook :
  // le vrai risque est que Claude Code coupe la requête (30 s) et la rejette.
  engine(on, () => ({ deny: 'request timed out after 30000 ms' }))
  const out = await $.prompt.submit({ text: ORIGINAL })
  expect(out.drop).toMatch(/n'a PAS été envoyé/)
})

test('erreur HTTP du moteur : le prompt est bloqué', async ($, on) => {
  engine(on, () => ({ value: { status: 500, ok: false, headers: {}, text: '' } }))
  const out = await $.prompt.submit({ text: ORIGINAL })
  expect(out.drop).toMatch(/throw/)
})

test('réponse illisible du moteur : le prompt est bloqué', async ($, on) => {
  engine(on, () => ({ value: { status: 200, ok: true, headers: {}, text: '<html>' } }))
  const out = await $.prompt.submit({ text: ORIGINAL })
  expect(out.drop).toMatch(/n'a PAS été envoyé/)
})

test('pièce jointe : refus explicite, le moteur n\'est même pas appelé', async ($, on) => {
  let calls = 0
  engine(on, () => {
    calls += 1
    return ok({ text: MASKED, entities: 2 })
  })
  const out = await $.prompt.submit({
    text: 'Lis cette photo de planning',
    attachments: [{ type: 'image', mediaType: 'image/png', data: 'AAAA' }],
  })
  expect(out.drop).toMatch(/pièces jointes/)
  expect(calls).toBe(0)
})

test('adresse non locale : refusée, rien ne part', { options: { endpoint: 'https://ecluse.example.com' } }, async ($, on) => {
  let calls = 0
  engine(on, () => {
    calls += 1
    return ok({ text: MASKED, entities: 2 })
  })
  const out = await $.prompt.submit({ text: ORIGINAL })
  expect(out.drop).toMatch(/seul le local/)
  expect(calls).toBe(0)
}, )

test('restauration à l\'affichage d\'une réponse', async ($, on) => {
  engine(on, () => ok({ text: 'Le dossier de Jean Dupont est complet.' }))
  on('ui.render', ($, e) => ({ type: 'Markdown', props: { text: e.props.text } }))
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'ecluse-sas',
      surface,
      component: 'AssistantMessage',
      requestId: 'msg-1',
      props: { text: 'Le dossier de [NOM_1] est complet.', isFirstOfReply: true },
    })
    const drawn = await ui.find({ type: 'Markdown' })
    expect(drawn?.props.text).toBe('Le dossier de Jean Dupont est complet.')
    await ui.unmount()
  }
})

// ---------- Outils : lecture pseudonymisée, écriture restaurée ----------

// Faux moteur cohérent : redact masque « Jean Dupont », restore le remet.
const fakeEngine = ($, e) => {
  const { text } = JSON.parse(e.init.body)
  if (e.url.endsWith('/v1/redact')) {
    const n = text.split('Jean Dupont').length - 1
    return ok({ text: text.split('Jean Dupont').join('[NOM_1]'), entities: n })
  }
  return ok({ text: text.split('[NOM_1]').join('Jean Dupont') })
}

test('Read : Claude reçoit le fichier pseudonymisé', async ($, on) => {
  engine(on, fakeEngine)
  on('tool.call', () => ({
    result: {
      type: 'text',
      file: { filePath: 'C:/plannings/s45.md', content: 'Garde : Jean Dupont', numLines: 1, startLine: 1, totalLines: 1 },
    },
  }))
  const out = await $.tool.call({ tool: 'Read', file_path: 'C:/plannings/s45.md' })
  expect(out.result.file.content).toBe('Garde : [NOM_1]')
  expect(JSON.stringify(out)).not.toContain('Dupont')
})

test('Read d\'une image : résultat retenu', async ($, on) => {
  engine(on, fakeEngine)
  on('tool.call', () => ({
    result: { type: 'image', file: { base64: 'iVBORw0KGgo=', type: 'image/png', originalSize: 8 } },
  }))
  const out = await $.tool.call({ tool: 'Read', file_path: 'C:/scan.png' })
  expect(out.deny).toMatch(/retenu/)
  expect(out.result).toBeUndefined()
})

test('Edit : les jetons sont restaurés avant l\'écriture sur disque', async ($, on) => {
  engine(on, fakeEngine)
  const received: unknown[] = []
  on('tool.call', ($, e) => {
    received.push(e)
    return { result: { filePath: e.file_path, oldString: e.old_string, newString: e.new_string } }
  })
  const out = await $.tool.call({
    tool: 'Edit',
    file_path: 'C:/plannings/s45.md',
    old_string: 'Garde : [NOM_1]',
    new_string: 'Garde : [NOM_1] (confirmé)',
  })
  expect(received[0]).toMatchObject({ old_string: 'Garde : Jean Dupont', new_string: 'Garde : Jean Dupont (confirmé)' })
  // Et ce que Claude relit du résultat est de nouveau pseudonymisé.
  expect(JSON.stringify(out)).not.toContain('Dupont')
})

test('WebFetch : les jetons ne sont JAMAIS restaurés vers l\'extérieur', async ($, on) => {
  engine(on, fakeEngine)
  const received: unknown[] = []
  on('tool.call', ($, e) => {
    received.push(e)
    return { result: { result: 'page' } }
  })
  await $.tool.call({ tool: 'WebFetch', url: 'https://exemple.fr/?q=[NOM_1]', prompt: 'qui est [NOM_1] ?' })
  expect(JSON.stringify(received[0])).not.toContain('Dupont')
})

test('Bash : la sortie est pseudonymisée', async ($, on) => {
  engine(on, fakeEngine)
  on('tool.call', () => ({ result: { stdout: 'Jean Dupont;CDI', stderr: '', interrupted: false } }))
  const out = await $.tool.call({ tool: 'Bash', command: 'type equipe.csv' })
  expect(out.result.stdout).toBe('[NOM_1];CDI')
})

test('moteur tombé après l\'outil : le résultat est retenu, rien en clair', async ($, on) => {
  let calls = 0
  engine(on, ($, e) => {
    calls += 1
    return { deny: 'connect ECONNREFUSED' }
  })
  on('tool.call', () => ({ result: { stdout: 'Jean Dupont;CDI', stderr: '', interrupted: false } }))
  const out = await $.tool.call({ tool: 'Bash', command: 'type equipe.csv' })
  expect(out.deny).toMatch(/retenu/)
  expect(JSON.stringify(out)).not.toContain('Dupont')
})
