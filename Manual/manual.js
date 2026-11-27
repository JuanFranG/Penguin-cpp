'use strict';
const search = document.querySelector('#window-search');
const cards = [...document.querySelectorAll('.window-card')];
const count = document.querySelector('#window-count');
function filterWindows() {
  const query = search.value.trim().toLocaleLowerCase();
  let visible = 0;
  for (const card of cards) {
    card.hidden = !card.textContent.toLocaleLowerCase().includes(query);
    if (!card.hidden) visible++;
  }
  count.textContent = `${visible} of ${cards.length} illustrated views`;
  document.querySelector('#no-windows').hidden = visible !== 0;
}
search.addEventListener('input', filterWindows);
filterWindows();
// A bookmarked window remains reachable even when a previous search hid it.
function revealHash() {
  let id;
  try { id = decodeURIComponent(location.hash.slice(1)); } catch { return; }
  const target = document.getElementById(id);
  if (target?.classList.contains('window-card') && target.hidden) {
    search.value = ''; filterWindows(); target.scrollIntoView();
  }
}
window.addEventListener('hashchange', revealHash);
revealHash();
const viewer = document.querySelector('#image-viewer');
let lastImageLink;
for (const link of document.querySelectorAll('a[data-viewer]')) {
  link.addEventListener('click', event => {
    if (typeof viewer.showModal !== 'function' || event.ctrlKey || event.metaKey) return;
    event.preventDefault(); lastImageLink = link;
    const source = link.querySelector('img');
    document.querySelector('#viewer-image').src = link.href;
    document.querySelector('#viewer-image').alt = source.alt;
    document.querySelector('#viewer-image').width = source.naturalWidth;
    document.querySelector('#viewer-image').height = source.naturalHeight;
    document.querySelector('#viewer-caption').textContent = source.alt;
    document.querySelector('#viewer-original').href = link.href;
    viewer.showModal();
  });
}
document.querySelector('#viewer-close').addEventListener('click', () => viewer.close());
viewer.addEventListener('click', event => { if (event.target === viewer) viewer.close(); });
viewer.addEventListener('close', () => lastImageLink?.focus());
