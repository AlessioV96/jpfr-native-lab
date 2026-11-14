(function () {
  'use strict';
  const $ = id => document.getElementById(id);
  const examples = {
    names: '田中さんが山田さんから手紙を受け取りました。',
    fees: '切符は四千二百円で、荷物の料金は別です。',
    family: '彼女には姉が二人いて、弟はいません。',
    rain: '雨が降っても、試合は中止しません。'
  };
  let active = null, generation = 0, deadline = null;
  function controls(busy) {
    for (const id of ['translate', 'check', 'example', 'strategy', 'source']) $(id).disabled = busy;
    $('stop').disabled = !busy;
  }
  function send(request) {
    if (!globalThis.browser?.runtime?.sendMessage) return Promise.reject(Error('Extension native non installée.'));
    return browser.runtime.sendMessage({channel: 'jpfr-native-v1', request});
  }
  async function invoke(method) {
    if (active) return;
    const id = crypto.randomUUID(), ticket = ++generation;
    const request = {version: 1, id, method, strategy: $('strategy').value};
    if (method === 'translate') request.text = $('source').value;
    try { JPFRNativeProtocol.validateRequest(request); }
    catch { $('status').textContent = 'Saisissez un texte japonais de 600 caractères au maximum.'; return; }
    active = id; controls(true);
    const localDeadline = setTimeout(() => stop('Délai dépassé. Aucun résultat final reçu.'), 40000);
    deadline = localDeadline;
    $('status').textContent = method === 'status' ? 'Vérification du moteur…' : 'Traduction en cours…';
    if (method === 'translate') $('result').textContent = '';
    try {
      const response = JPFRNativeProtocol.validateReply(await send(request), request);
      if (ticket !== generation) return;
      if (!response.ok) {
        $('status').textContent = response.message || 'Le moteur n’a pas abouti.';
      } else if (method === 'status') {
        $('status').textContent = response.sessionReady
          ? 'Le moteur indique que les langues sont prêtes.'
          : 'Ouvrez l’application JPFR et préparez le japonais et le français.';
      } else {
        $('result').textContent = response.text;
        $('status').textContent = 'Texte reçu. Sa fidélité reste à vérifier.';
      }
    } catch { if (ticket === generation) $('status').textContent = 'La partie native ne répond pas. Vérifiez son installation.'; }
    finally {
      clearTimeout(localDeadline);
      if (ticket === generation) { deadline = null; active = null; controls(false); }
    }
  }
  function stop(message = 'Arrêt demandé. Les réponses tardives sont ignorées.') {
    if (!active) return;
    const targetRequestID = active;
    clearTimeout(deadline); deadline = null;
    generation++; active = null; controls(false);
    $('status').textContent = message;
    void send({version: 1, id: crypto.randomUUID(), method: 'cancel', targetRequestID}).catch(() => {});
  }
  $('example').onchange = () => { $('source').value = examples[$('example').value]; };
  $('translate').onclick = () => invoke('translate');
  $('check').onclick = () => invoke('status');
  $('stop').onclick = () => stop();
  window.addEventListener('pagehide', () => stop());
})();
