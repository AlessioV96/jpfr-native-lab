import fs from 'node:fs/promises';
const valid = {version: 1, id: 'test-1', method: 'translate', strategy: 'highFidelity', text: 'こんにちは。'};
const vectors = [
  ['texte simple', valid, true],
  ['version inconnue', {...valid, version: 2}, false],
  ['id vide', {...valid, id: ''}, false],
  ['id avec espace', {...valid, id: 'a b'}, false],
  ['id trop long', {...valid, id: 'a'.repeat(81)}, false],
  ['opération inconnue', {...valid, method: 'readVideo'}, false],
  ['préférence inconnue', {...valid, strategy: 'automatic'}, false],
  ['texte vide', {...valid, text: ' \t\n'}, false],
  ['600 scalaires', {...valid, text: 'あ'.repeat(600)}, true],
  ['601 scalaires', {...valid, text: 'あ'.repeat(601)}, false],
  ['600 emoji', {...valid, text: '😀'.repeat(600)}, true],
  ['601 emoji', {...valid, text: '😀'.repeat(601)}, false],
  ['texte numérique refusé', {...valid, text: 12}, false],
  ['statut', {version: 1, id: 'status-1', method: 'status', strategy: 'lowLatency'}, true],
  ['statut avec texte', {version: 1, id: 'status-1', method: 'status', strategy: 'lowLatency', text: 'あ'}, false],
  ['annulation', {version: 1, id: 'stop-1', method: 'cancel', targetRequestID: 'test-1'}, true],
  ['annulation sans cible', {version: 1, id: 'stop-1', method: 'cancel'}, false],
  ['annulation avec préférence', {version: 1, id: 'stop-1', method: 'cancel', targetRequestID: 'test-1', strategy: 'highFidelity'}, false]
].map(([name, request, valid]) => ({name, request: JSON.stringify(request), valid}));
await fs.mkdir(new URL('../Tests', import.meta.url), {recursive: true});
await fs.writeFile(new URL('../Tests/contract-vectors.json', import.meta.url), JSON.stringify(vectors, null, 2));
console.log(vectors.length + ' vecteurs de contrat écrits.');
