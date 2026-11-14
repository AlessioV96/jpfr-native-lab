'use strict';
const bridge = JPFRNativeRPC.createBridge(
  request => browser.runtime.sendNativeMessage('org.jpfr.prototype.safarilab', request)
);
browser.runtime.onMessage.addListener((message, sender) => {
  if (message?.channel !== 'jpfr-native-v1') return;
  if (sender.id !== browser.runtime.id)
    return Promise.resolve(JPFRNativeProtocol.failure('invalid', 'unauthorized', 'Émetteur refusé.'));
  return bridge.invoke(message.request);
});
