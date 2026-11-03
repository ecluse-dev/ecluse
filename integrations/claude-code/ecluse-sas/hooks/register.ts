import type { Register } from 'claude-code'

// Prototype du sas Écluse pour Claude Code.
//
// Ligne éditoriale : « refuser plutôt que rater silencieusement ».
// - prompt.submit : le prompt part pseudonymisé, ou ne part pas.
// - AssistantMessage : les tokens ([NOM_1]…) sont restaurés à l'AFFICHAGE
//   seulement ; ce que Claude a lu et ce qui est stocké reste pseudonymisé.
//
// La table de correspondance ne vit jamais ici : elle reste dans le moteur
// Écluse local (Dart), indexée par l'id de session.

const LOOPBACK = /^http:\/\/(127\.0\.0\.1|localhost|\[::1\])(:\d+)?$/
const TOKEN = /\[[A-Z_]+_\d+\]/

// Restaurations déjà calculées, pour ne pas rappeler le moteur à chaque redessin.
const restored = new Map<string, string>()
let masked = 0

async function redact($, endpoint: string, session: string, text: string) {
  const res = await $.http.fetch(endpoint + '/v1/redact', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ session, text }),
  })
  if (!res.ok) throw new Error('moteur Écluse : HTTP ' + res.status)
  const out = JSON.parse(res.text)
  if (typeof out.text !== 'string' || typeof out.entities !== 'number') {
    throw new Error('moteur Écluse : réponse illisible')
  }
  return out as { text: string; entities: number }
}

async function restore($, endpoint: string, session: string, text: string) {
  const res = await $.http.fetch(endpoint + '/v1/restore', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ session, text }),
  })
  if (!res.ok) throw new Error('moteur Écluse : HTTP ' + res.status)
  const out = JSON.parse(res.text)
  if (typeof out.text !== 'string') throw new Error('moteur Écluse : réponse illisible')
  return out.text as string
}

// Outils qui travaillent sur les fichiers locaux : leurs entrées sont
// restaurées (Claude n'a vu que des jetons, le disque doit garder les vraies
// valeurs). Tout autre outil (Bash, WebFetch, WebSearch, MCP…) reçoit les
// jetons tels quels : aucune vraie valeur ne doit pouvoir sortir par là.
const RESTORE_INPUT = new Set(['Read', 'Write', 'Edit', 'MultiEdit', 'NotebookEdit', 'Glob', 'Grep'])

// Champs techniques jamais envoyés au moteur.
const SKIP_KEYS = new Set(['tool', 'tool_use_id', 'agentId', 'type', 'mode'])

// Restaure les jetons dans chaque chaîne de `value` (entrée d'un outil).
async function restoreDeep($, endpoint: string, session: string, value: unknown, key?: string): Promise<unknown> {
  if (typeof value === 'string') {
    return key !== undefined && SKIP_KEYS.has(key) || !TOKEN.test(value)
      ? value
      : await restore($, endpoint, session, value)
  }
  if (Array.isArray(value)) {
    const out: unknown[] = []
    for (const item of value) out.push(await restoreDeep($, endpoint, session, item))
    return out
  }
  if (value !== null && typeof value === 'object') {
    const out: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(value)) out[k] = await restoreDeep($, endpoint, session, v, k)
    return out
  }
  return value
}

// Pseudonymise chaque chaîne de `value` (résultat d'un outil). Un contenu
// binaire (image, PDF : champ base64) n'est pas vérifiable : on refuse.
async function maskDeep($, endpoint: string, session: string, value: unknown, key?: string): Promise<unknown> {
  if (typeof value === 'string') {
    if (key === 'base64') throw new Error('contenu binaire non vérifiable')
    if (key !== undefined && SKIP_KEYS.has(key) || value.length < 4) return value
    const out = await redact($, endpoint, session, value)
    masked += out.entities
    return out.text
  }
  if (Array.isArray(value)) {
    const out: unknown[] = []
    for (const item of value) out.push(await maskDeep($, endpoint, session, item))
    return out
  }
  if (value !== null && typeof value === 'object') {
    const out: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(value)) out[k] = await maskDeep($, endpoint, session, v, k)
    return out
  }
  return value
}

export const register: Register = (on, options) => {
  const endpoint = String(options.endpoint ?? '').replace(/\/+$/, '')
  const isLoopback = LOOPBACK.test(endpoint)

  // 1. Porte d'entrée : chaque prompt passe par le moteur, sinon il ne part pas.
  on('prompt.submit', async ($, e, next) => {
    if (!isLoopback) {
      return { drop: 'Écluse : adresse du moteur refusée (' + endpoint + '), seul le local est accepté. Rien n\'a été envoyé.' }
    }
    // Images et pièces jointes : hors périmètre d'Écluse, refus explicite.
    if (e.attachments && e.attachments.length > 0) {
      return { drop: 'Écluse : les images et pièces jointes ne sont pas vérifiables, le prompt n\'a pas été envoyé. Retire-les ou décris-les en texte.' }
    }
    // Commande slash : la réécriture n'est pas appliquée par Claude Code.
    // Limite connue du prototype : on laisse passer et on le signale.
    if (e.command) {
      $.ui.log('Écluse : commande /' + e.command.name + ' transmise SANS pseudonymisation (limite du prototype).')
      return next(e)
    }
    const session = await $.session.id()
    const out = await redact($, endpoint, session, e.text)
    masked += out.entities
    $.ui.status('Écluse : ' + masked + ' entité(s) masquée(s)')
    return next({ ...e, text: out.text })
  }).catch(($, e, next) =>
    // Le hook a échoué (moteur absent, réponse illisible, dépassement de temps).
    // Avant next : on bloque. Après next : le prompt était déjà parti pseudonymisé.
    next.called
      ? next(e)
      : { drop: 'Écluse : le moteur local n\'a pas répondu (' + next.error.kind + '), le prompt n\'a PAS été envoyé.' },
  )

  // 2. Outils : ce que Claude lit est pseudonymisé, ce qu'il écrit sur le
  //    disque est restauré.
  on('tool.call', async ($, e, next) => {
    if (!isLoopback) return { deny: 'Écluse : adresse du moteur refusée, outil bloqué.' }
    const session = await $.session.id()
    const input = RESTORE_INPUT.has(e.tool)
      ? ((await restoreDeep($, endpoint, session, e)) as typeof e)
      : e
    const ran = await next(input)
    if (ran.deny !== undefined) return ran
    const result = await maskDeep($, endpoint, session, ran.result)
    $.ui.status('Écluse : ' + masked + ' entité(s) masquée(s)')
    // Notre propre { result } : Claude Code le remet en forme pour Claude
    // à partir de la version pseudonymisée, pas de l'original.
    return { result, isError: ran.isError } as typeof ran
  }).catch(($, e, next) =>
    // Quel que soit le moment de l'échec, Claude ne reçoit rien en clair :
    // avant l'outil, il ne tourne pas ; après, son résultat est retenu.
    ({
      deny: 'Écluse : ' + (next.called
        ? 'résultat de ' + e.tool + ' retenu, le moteur local n\'a pas pu le pseudonymiser'
        : e.tool + ' bloqué, le moteur local n\'a pas répondu') + ' (' + next.error.kind + ').',
    }),
  )

  // 3. Porte de sortie : restauration à l'affichage uniquement.
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    const text = e.props.text
    if (!isLoopback || !TOKEN.test(text)) return next(e)
    let clear = restored.get(text)
    if (clear === undefined) {
      const session = await $.session.id()
      clear = await restore($, endpoint, session, text)
      restored.set(text, clear)
    }
    return next({ ...e, props: { ...e.props, text: clear } })
  })
  // En cas d'échec de la restauration, le hook est sauté : la réponse
  // s'affiche avec ses tokens. Aucune donnée ne sort, donc pas de .catch.
}
