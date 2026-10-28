// OPTIONAL TEMPLATE: a guard for the privacy screening and PIA process
// (RULES.md#privacy in github.com/garethrhughes/skills).
//
// Install it only if the project wants a mechanical check. Copy it to
// scripts/__tests__/privacy-screening.test.mjs and run it with
//   node --test scripts/__tests__/privacy-screening.test.mjs
// It needs Node 18+ and no dependencies. Set the numbers below so documents written
// before the project adopted the screening are not checked, then break it once (delete a
// screening from a copy of a feature doc, point PRIVACY_FEATURES_DIR at the copy) and
// watch it fail before you rely on it.
//
// What it checks: every screened feature doc and proposal has a "## Privacy screening"
// with the five standard questions answered Yes/No with a reason and a result line; a
// Yes links a PIA that exists; each PIA has the template's headings, its regimes field
// and a valid decision, and links back to a document whose screening links it; the
// privacy README indexes every PIA.
// What it cannot check: that an answer is true. Review and infosec do that.

import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const FEATURES_DIR = process.env.PRIVACY_FEATURES_DIR
  ? path.resolve(process.env.PRIVACY_FEATURES_DIR)
  : path.join(ROOT, 'docs', 'features');
const PROPOSALS_DIR = process.env.PRIVACY_PROPOSALS_DIR
  ? path.resolve(process.env.PRIVACY_PROPOSALS_DIR)
  : path.join(ROOT, 'docs', 'proposals');
const PRIVACY_DIR = process.env.PRIVACY_DIR
  ? path.resolve(process.env.PRIVACY_DIR)
  : path.join(ROOT, 'docs', 'privacy');

/** The first feature document and proposal number the rule applies to. Set these when installing. */
export const FIRST_SCREENED_FEATURE = 1;
export const FIRST_SCREENED_PROPOSAL = 1;

/** The five questions, word for word as docs/privacy/README.md gives them; a test keeps the two equal. */
export const SCREENING_QUESTIONS = [
  'Does it collect, derive, log, store, expose or send any new data about a person (identifiers included: account ids, entity ids, key prefixes, IPs, emails, timestamps, usage or behaviour)?',
  'Does it change who can see existing data (the user, an operator or admin, another user, a processor or sub-processor, an AI agent or integration)?',
  'Does it change how long data is kept, or how it is deleted, exported or purged (account deletion, purge jobs, backups, archives)?',
  'Does it add or change a third party, a region, a model, analytics, telemetry or a network call that carries user data?',
  'Does it derive new information about people (profiling, inference, embeddings, activity summaries)?',
];

export const PIA_HEADINGS = [
  'What changes',
  'Data',
  'Necessity and proportionality',
  'Transparency',
  'User rights',
  'Harms to individuals',
  'Confidentiality checks',
  'Processors and transfers',
  'Applicable regimes and lawful basis',
  'Residual risk and decision',
  'Review',
];

const NOT_PIAS = new Set(['README.md', 'TEMPLATE-pia.md', 'data-inventory.md']);
const PIA_NAME = /^\d{4}-[a-z0-9-]+\.md$/;
const DOC_NAME = /^(\d{4})-[A-Za-z0-9-]+\.md$/; // feature docs may carry a ticket key (0007-PLAT-12-x.md)
const DECISIONS = ['proceed', 'proceed with conditions', 'stop'];

const normalise = (s) => s.replace(/\s+/g, ' ').trim().toLowerCase();

/** The text's lines with fenced code blocks blanked, so a quoted template is never read as the document's own. */
export function proseLines(text) {
  let fence = null;
  return text.split('\n').map((line) => {
    const marker = /^\s{0,3}(`{3,}|~{3,})/.exec(line);
    if (fence === null) {
      if (marker === null) return line;
      fence = marker[1];
      return '';
    }
    if (marker !== null && marker[1][0] === fence[0] && marker[1].length >= fence.length && line.trim() === marker[1]) {
      fence = null;
    }
    return '';
  });
}

/** The lines of the `## <heading>` section up to the next `## ` heading, or null when there is none. */
export function sectionLines(text, heading) {
  const lines = proseLines(text);
  const start = lines.findIndex((line) => line.trim() === `## ${heading}`);
  if (start === -1) return null;
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((line) => line.startsWith('## '));
  return end === -1 ? rest : rest.slice(0, end);
}

/** PIA file names a line links to (`../privacy/NNNN-x.md` or `docs/privacy/NNNN-x.md`). */
export function linkedPias(line) {
  return [...line.matchAll(/\]\((?:(?:\.\.\/)+|docs\/)privacy\/(\d{4}-[a-z0-9-]+\.md)\)/g)].map((m) => m[1]);
}

/** Every problem with a document's `## Privacy screening`. `piaExists(name)` says whether docs/privacy/<name> exists. */
export function screeningProblems(text, piaExists, questions = SCREENING_QUESTIONS) {
  const section = sectionLines(text, 'Privacy screening');
  if (section === null) return ['no "## Privacy screening" section'];

  const problems = [];
  const answers = new Map();
  for (const line of section) {
    if (!/^\|\s*\d+\s*\|/.test(line)) continue;
    const cells = line.split('|').slice(1, -1).map((cell) => cell.trim());
    if (cells.length !== 4) {
      problems.push(`question ${cells[0]}: expected 4 cells (#, question, answer, why), found ${cells.length}`);
      continue;
    }
    const [number, question, answer, why] = cells;
    if (answers.has(number)) problems.push(`question ${number} is answered twice`);
    if (!/^(yes|no)$/i.test(answer)) problems.push(`question ${number}: answer "${answer}" is not Yes or No`);
    const standard = questions[Number(number) - 1];
    if (standard === undefined) problems.push(`question ${number} is not one of the five`);
    else if (normalise(question) !== normalise(standard)) {
      problems.push(`question ${number} is not the standard question (copy it from docs/privacy/README.md)`);
    }
    if (why === '') problems.push(`question ${number}: no one-line reason`);
    answers.set(number, answer.toLowerCase());
  }
  for (let n = 1; n <= questions.length; n += 1) {
    if (!answers.has(String(n))) problems.push(`question ${n} is not answered`);
  }

  const result = section.find((line) => line.startsWith('**Result:**'));
  if (result === undefined) return [...problems, 'no "**Result:**" line'];

  const links = linkedPias(result);
  if ([...answers.values()].includes('yes')) {
    if (links.length === 0) problems.push('a question is answered Yes but the result links no PIA under docs/privacy/');
    for (const name of links) {
      if (!piaExists(name)) problems.push(`the result links docs/privacy/${name}, which does not exist`);
    }
  } else {
    const why = /^\*\*Result:\*\*\s*No PIA:\s*(.*)$/.exec(result);
    if (why === null || why[1].trim().length < 10) {
      problems.push('every answer is No but the result is not "No PIA: <one sentence why>"');
    }
  }
  return problems;
}

/** Every problem with a PIA's shape: headings, regimes field, decision. */
export function piaProblems(text) {
  const problems = [];
  for (const heading of PIA_HEADINGS) {
    if (sectionLines(text, heading) === null) problems.push(`no "## ${heading}" section`);
  }
  const regimes = sectionLines(text, 'Applicable regimes and lawful basis');
  if (regimes !== null) {
    const prose = regimes.join('\n').replace(/<!--[\s\S]*?-->/g, '').trim();
    if (prose === '') problems.push('"Applicable regimes and lawful basis" is empty (write "legal review needed" until it is filled)');
  }
  const decisionSection = sectionLines(text, 'Residual risk and decision');
  if (decisionSection !== null) {
    const line = decisionSection.find((l) => /^\s*-\s*\*\*Decision:\*\*/.test(l));
    const value = line === undefined ? '' : normalise(line.replace(/^\s*-\s*\*\*Decision:\*\*/, ''));
    if (!DECISIONS.includes(value)) problems.push(`decision "${value}" is not one of: ${DECISIONS.join(', ')}`);
  }
  return problems;
}

/** The feature docs and proposals a PIA's header (the text before its first `## `) links to, relative to docs/. */
export function piaSources(text) {
  const lines = proseLines(text);
  const first = lines.findIndex((line) => line.startsWith('## '));
  const header = (first === -1 ? lines : lines.slice(0, first)).join('\n').replace(/<!--[\s\S]*?-->/g, '');
  return [...header.matchAll(/\]\(\.\.\/((?:features|proposals)\/\d{4}-[A-Za-z0-9-]+\.md)\)/g)].map((m) => m[1]);
}

function screenedDocs(dir, first) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => {
      const m = DOC_NAME.exec(name);
      return m !== null && Number(m[1]) >= first;
    })
    .map((name) => ({ name, text: readFileSync(path.join(dir, name), 'utf8') }));
}

function pias() {
  if (!existsSync(PRIVACY_DIR)) return [];
  return readdirSync(PRIVACY_DIR)
    .filter((name) => PIA_NAME.test(name) && !NOT_PIAS.has(name))
    .map((name) => ({ name, text: readFileSync(path.join(PRIVACY_DIR, name), 'utf8') }));
}

const piaExists = (name) => existsSync(path.join(PRIVACY_DIR, name));

// ── The checker can fail (examples that must be refused) ────────────────────

const row = (n, answer, why = 'a reason') => `| ${n} | ${SCREENING_QUESTIONS[n - 1]} | ${answer} | ${why} |`;
const screening = (answers, result) =>
  ['## Privacy screening', '', '| # | Question | Answer | Why |', '|---|---|---|---|',
    ...answers.map((a, i) => row(i + 1, a)), '', result].join('\n');

test('the checker accepts a complete all-No screening', () => {
  assert.deepEqual(screeningProblems(screening(['No', 'No', 'No', 'No', 'No'], '**Result:** No PIA: nothing here touches personal data.'), () => true), []);
});

test('the checker refuses a document with no screening', () => {
  assert.deepEqual(screeningProblems('# A feature\n', () => true), ['no "## Privacy screening" section']);
});

test('the checker refuses a screening quoted only inside a code fence', () => {
  const fenced = '```markdown\n' + screening(['No', 'No', 'No', 'No', 'No'], '**Result:** No PIA: nothing here.') + '\n```\n';
  assert.deepEqual(screeningProblems(fenced, () => true), ['no "## Privacy screening" section']);
});

test('the checker refuses a Yes with no PIA link, and a link to a missing PIA', () => {
  const noLink = screening(['Yes', 'No', 'No', 'No', 'No'], '**Result:** No PIA: but question 1 said yes.');
  assert.ok(screeningProblems(noLink, () => true).some((p) => p.includes('links no PIA')));
  const missing = screening(['Yes', 'No', 'No', 'No', 'No'], '**Result:** PIA: [docs/privacy/0001-x.md](../privacy/0001-x.md)');
  assert.ok(screeningProblems(missing, () => false).some((p) => p.includes('does not exist')));
});

test('the checker refuses a reworded question, a missing answer and an empty reason', () => {
  const text = screening(['No', 'No', 'No', 'No'], '**Result:** No PIA: nothing here touches personal data.')
    .replace(SCREENING_QUESTIONS[1], 'Does anyone new see data?')
    .replace('| 3 | ' + SCREENING_QUESTIONS[2] + ' | No | a reason |', '| 3 | ' + SCREENING_QUESTIONS[2] + ' | No |  |');
  const problems = screeningProblems(text, () => true);
  assert.ok(problems.some((p) => p.includes('question 2 is not the standard question')));
  assert.ok(problems.some((p) => p.includes('question 3: no one-line reason')));
  assert.ok(problems.some((p) => p.includes('question 5 is not answered')));
});

test('the checker refuses a PIA without a decision or a heading', () => {
  const problems = piaProblems('## What changes\n\nx\n\n## Residual risk and decision\n\n- **Decision:** proceed | stop\n');
  assert.ok(problems.some((p) => p.includes('no "## Data" section')));
  assert.ok(problems.some((p) => p.includes('is not one of')));
});

// ── The repository ──────────────────────────────────────────────────────────

test('the privacy README states the same five questions as this guard', () => {
  const readme = readFileSync(path.join(PRIVACY_DIR, 'README.md'), 'utf8');
  for (const [i, question] of SCREENING_QUESTIONS.entries()) {
    assert.ok(normalise(readme).includes(normalise(`| ${i + 1} | ${question} |`)), `README is missing question ${i + 1} word for word`);
  }
});

for (const [label, dir, first] of [
  ['feature document', FEATURES_DIR, FIRST_SCREENED_FEATURE],
  ['proposal', PROPOSALS_DIR, FIRST_SCREENED_PROPOSAL],
]) {
  for (const doc of screenedDocs(dir, first)) {
    test(`${label} ${doc.name} has a complete privacy screening`, () => {
      assert.deepEqual(screeningProblems(doc.text, piaExists), []);
    });
  }
}

for (const pia of pias()) {
  test(`PIA ${pia.name} has the template's headings, a regimes field and a decision`, () => {
    assert.deepEqual(piaProblems(pia.text), []);
  });

  test(`PIA ${pia.name} links a feature doc or proposal whose screening links it back`, () => {
    const sources = piaSources(pia.text);
    assert.ok(sources.length > 0, 'the header links no docs/features/ or docs/proposals/ document');
    for (const source of sources) {
      const file = path.join(ROOT, 'docs', source);
      assert.ok(existsSync(file), `docs/${source} does not exist`);
      const result = (sectionLines(readFileSync(file, 'utf8'), 'Privacy screening') ?? []).find((l) => l.startsWith('**Result:**')) ?? '';
      assert.ok(linkedPias(result).includes(pia.name), `docs/${source}'s screening result does not link ${pia.name}`);
    }
  });

  test(`the privacy README indexes PIA ${pia.name}`, () => {
    const index = sectionLines(readFileSync(path.join(PRIVACY_DIR, 'README.md'), 'utf8'), 'Index') ?? [];
    assert.ok(index.some((line) => line.includes(`](${pia.name})`)), `docs/privacy/README.md ## Index does not link ${pia.name}`);
  });
}
