import fs from 'node:fs/promises';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
const base = new URL('../Resources/', import.meta.url);
const context = vm.createContext({TextEncoder, setTimeout, clearTimeout, crypto: webcrypto});
for (const name of ['protocol.js', 'native-rpc.js'])
  vm.runInContext(await fs.readFile(new URL(name, base), 'utf8'), context, {filename: name});
const P = context.JPFRNativeProtocol, RPC = context.JPFRNativeRPC;
const vectors = JSON.parse(await fs.readFile(new URL('../Tests/contract-vectors.json', import.meta.url), 'utf8'));
for (const vector of vectors) {
  let accepted = true;
  try { P.validateRequest(JSON.parse(vector.request)); } catch { accepted = false; }
  assert.equal(accepted, vector.valid, vector.name);
}
const checks = [{name: vectors.length + ' vecteurs de contrat JavaScript', state: 'passed'}];
const request = (id = 'test-1') => ({version: 1, id, method: 'translate', strategy: 'highFidelity', text: 'こんにちは。'});
const reply = r => ({version: 1, provider: 'AppleTranslation', sourceLanguage: 'ja', targetLanguage: 'fr',
  id: r.id, ok: true, text: 'Sortie simulée pour le contrôle de transport.', effectiveModelMeasured: false});
let calls = 0;
const simple = RPC.createBridge(async r => { calls++; return reply(r); });
assert.equal((await simple.invoke({...request(), text: ''})).errorCode, 'invalid-request');
assert.equal(calls, 0);
assert.equal((await simple.invoke(request())).ok, true);
checks.push({name: 'Rejet avant appel natif et réponse valide corrélée', state: 'passed'});
const incorrect = RPC.createBridge(async r => ({...reply(r), id: 'old-request'}));
assert.equal((await incorrect.invoke(request())).errorCode, 'invalid-reply');
const absent = RPC.createBridge(async () => { throw Error('indisponible simulé'); });
assert.equal((await absent.invoke(request())).errorCode, 'native-unavailable');
checks.push({name: 'Mauvais identifiant et moteur absent signalés sans faux français', state: 'passed'});
let finishOriginal;
const events = [];
const delayed = RPC.createBridge(r => {
  events.push(r);
  if (r.method === 'cancel') return Promise.resolve({...reply(r), text: undefined});
  return new Promise(resolve => { finishOriginal = () => resolve(reply(r)); });
}, {timeoutMs: 1000});
const first = delayed.invoke(request());
await new Promise(resolve => setTimeout(resolve, 0));
assert.equal((await delayed.invoke(request('test-2'))).errorCode, 'busy');
const stopped = await delayed.invoke({version: 1, id: 'stop-1', method: 'cancel', targetRequestID: 'test-1'});
assert.equal(stopped.ok, true);
assert.equal((await first).errorCode, 'cancelled');
finishOriginal();
await new Promise(resolve => setTimeout(resolve, 0));
assert.equal(events.filter(x => x.method === 'translate').length, 1);
checks.push({name: 'Une demande active, arrêt local et réponse tardive ignorée', state: 'passed'});
const timeoutEvents = [];
const silent = RPC.createBridge(r => { timeoutEvents.push(r); return new Promise(() => {}); }, {timeoutMs: 20});
assert.equal((await silent.invoke(request())).errorCode, 'timeout');
await new Promise(resolve => setTimeout(resolve, 0));
assert.ok(timeoutEvents.some(x => x.method === 'cancel' && x.targetRequestID === 'test-1'));
checks.push({name: 'Délai muet borné et annulation native demandée', state: 'passed'});
const manifest = JSON.parse(await fs.readFile(new URL('manifest.json', base), 'utf8'));
assert.deepEqual(manifest.permissions, ['nativeMessaging']);
assert.equal(manifest.content_scripts, undefined);
assert.equal(manifest.host_permissions, undefined);
checks.push({name: 'Aucune permission de lecture des sites ou de capture', state: 'passed'});
const report = {date: new Date().toISOString(), scope: 'Contrat et transport simulés sous Node (' + process.platform + ') ; aucun framework Apple exécuté',
  nativeFrameworkExecuted: false, swiftCompiled: false, state: 'passed', checks};
if (process.argv.includes('--report')) {
  const target = new URL('../../resultats/native-bridge-contract.json', import.meta.url);
  await fs.mkdir(new URL('../../resultats/', import.meta.url), {recursive: true});
  await fs.writeFile(target, JSON.stringify(report, null, 2));
}
console.log(JSON.stringify(report));
