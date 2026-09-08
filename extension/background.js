'use strict';

const HOST_NAME = 'com.lwan.mutebar';
const MEET_URL = 'https://meet.google.com/*';

let port = null;
// tabId -> latest state; aggregated so a stale tab can't clobber the live call
const tabStates = new Map();

function connect() {
  try {
    port = chrome.runtime.connectNative(HOST_NAME);
  } catch (e) {
    port = null;
    setTimeout(connect, 2000); // host not registered yet; retry
    return;
  }
  port.onMessage.addListener(onNativeMessage);
  port.onDisconnect.addListener(() => {
    // Expected whenever the MuteBar app restarts; ack to silence Chrome's
    // "Unchecked runtime.lastError" warning.
    void chrome.runtime.lastError;
    port = null;
    setTimeout(connect, 2000);
  });
}

function onNativeMessage(msg) {
  if (!msg || !msg.type) return;
  if (msg.type === 'toggle' || msg.type === 'getState') sendToMeetTabs(msg);
  // 'ping' / 'pong' are keepalive only
}

function sendToMeetTabs(msg) {
  chrome.tabs.query({ url: MEET_URL }, (tabs) => {
    for (const tab of tabs) {
      chrome.tabs.sendMessage(tab.id, msg).catch(() => {
        if (msg.type === 'state') tabStates.delete(tab.id);
      });
    }
  });
}

// Aggregate: any tab in a meeting wins; prefer the most recently updated one.
let lastAggregate = null;
function pushAggregate() {
  const inMeeting = [...tabStates.entries()].filter(([, s]) => s.inMeeting);
  let aggregate;
  if (inMeeting.length > 0) {
    aggregate = { type: 'state', inMeeting: true, muted: inMeeting[inMeeting.length - 1][1].muted };
  } else if (tabStates.size > 0) {
    aggregate = { type: 'state', inMeeting: false, muted: null };
  } else {
    return; // no Meet tabs known yet
  }
  const same = lastAggregate && lastAggregate.inMeeting === aggregate.inMeeting
    && lastAggregate.muted === aggregate.muted;
  if (!same) {
    lastAggregate = aggregate;
    if (port) {
      try { port.postMessage(aggregate); } catch (_) {}
    }
  }
}

chrome.runtime.onMessage.addListener((msg, sender) => {
  if (msg && msg.type === 'state' && sender.tab) {
    tabStates.set(sender.tab.id, { inMeeting: !!msg.inMeeting, muted: msg.muted ?? null });
    pushAggregate();
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  tabStates.delete(tabId);
  pushAggregate();
});

// Keepalive: MV3 service workers sleep after ~30s idle; port traffic resets it.
setInterval(() => {
  if (port) {
    try { port.postMessage({ type: 'ping' }); } catch (_) {}
  }
}, 20000);

connect();
