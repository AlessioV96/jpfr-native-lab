(function (root) {
  'use strict';
  const strategies = new Set(['highFidelity', 'lowLatency']);
  const validID = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,80}$/.test(value);
  function validateRequest(value) {
    if (!value || value.version !== 1 || !validID(value.id)) throw Error('Demande invalide.');
    const request = {version: 1, id: value.id, method: value.method};
    if (value.method === 'translate') {
      if (!strategies.has(value.strategy) || typeof value.text !== 'string' ||
          !value.text.trim() || [...value.text].length > 600 ||
          new TextEncoder().encode(value.text).length > 4096 || value.targetRequestID != null)
        throw Error('Texte ou préférence invalide.');
      request.strategy = value.strategy;
      request.text = value.text;
    } else if (value.method === 'status') {
      if (!strategies.has(value.strategy) || value.text != null || value.targetRequestID != null)
        throw Error('Préférence invalide.');
      request.strategy = value.strategy;
    } else if (value.method === 'cancel') {
      if (!validID(value.targetRequestID) || value.text != null || value.strategy != null)
        throw Error('Annulation invalide.');
      request.targetRequestID = value.targetRequestID;
    } else throw Error('Opération inconnue.');
    return request;
  }
  function failure(id, code, message) {
    return {version: 1, provider: 'AppleTranslation', id, ok: false,
      sourceLanguage: 'ja', targetLanguage: 'fr', effectiveModelMeasured: false,
      errorCode: code, message};
  }
  function validateReply(value, request) {
    if (!value || value.version !== 1 || value.id !== request.id ||
        value.provider !== 'AppleTranslation' || typeof value.ok !== 'boolean' ||
        value.sourceLanguage !== 'ja' || value.targetLanguage !== 'fr')
      throw Error('Réponse native inattendue.');
    if (value.ok && request.method === 'translate' &&
        (typeof value.text !== 'string' || !value.text.trim() || value.text.length > 20000))
      throw Error('Texte traduit absent ou invalide.');
    if (!value.ok && typeof value.errorCode !== 'string') throw Error('Erreur native mal formée.');
    return value;
  }
  root.JPFRNativeProtocol = Object.freeze({validID, validateRequest, validateReply, failure});
})(globalThis);
