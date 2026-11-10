const menu = document.querySelector<HTMLButtonElement>('.mobile-toggle');
const navigation = document.querySelector('#site-navigation');
menu?.addEventListener('click', () => {
  const open = menu.getAttribute('aria-expanded') !== 'true';
  menu.setAttribute('aria-expanded', String(open));
  navigation?.classList.toggle('is-open', open);
});

document.querySelectorAll<HTMLPreElement>('pre').forEach(pre => {
  const code = pre.querySelector('code');
  if (!code) return;
  const wrapper = document.createElement('div');
  wrapper.className = 'code-block';
  pre.before(wrapper);
  wrapper.append(pre);
  pre.tabIndex = 0;
  const button = document.createElement('button');
  button.className = 'copy-code';
  button.textContent = 'Copy';
  button.setAttribute('aria-label', 'Copy code to clipboard');
  button.setAttribute('aria-live', 'polite');
  wrapper.append(button);
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(code.textContent ?? '');
      button.textContent = 'Copied!';
    } catch {
      button.textContent = 'Select to copy';
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(code);
      selection?.removeAllRanges();
      selection?.addRange(range);
    }
    window.setTimeout(() => { button.textContent = 'Copy'; }, 2200);
  });
});

document.querySelectorAll('.prose table').forEach(table => {
  const wrapper = document.createElement('div');
  wrapper.className = 'table-wrap';
  wrapper.tabIndex = 0;
  wrapper.setAttribute('role', 'region');
  wrapper.setAttribute('aria-label', 'Scrollable comparison table');
  table.before(wrapper);
  wrapper.append(table);
});

const tabs = Array.from(document.querySelectorAll<HTMLButtonElement>('[data-code-tab]'));
function selectTab(tab: HTMLButtonElement) {
  tabs.forEach(item => {
    const active = item === tab;
    item.setAttribute('aria-selected', String(active));
    item.tabIndex = active ? 0 : -1;
    const panel = document.getElementById(item.getAttribute('aria-controls') ?? '');
    if (panel) panel.hidden = !active;
  });
}
tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectTab(tab));
  tab.addEventListener('keydown', event => {
    let target = index;
    if (event.key === 'ArrowRight') target = (index + 1) % tabs.length;
    else if (event.key === 'ArrowLeft') target = (index - 1 + tabs.length) % tabs.length;
    else if (event.key === 'Home') target = 0;
    else if (event.key === 'End') target = tabs.length - 1;
    else return;
    event.preventDefault(); selectTab(tabs[target]); tabs[target].focus();
  });
});

type SearchEntry = { title: string; description: string; section: string; url: string; text: string };
const dialog = document.querySelector<HTMLDialogElement>('.search-dialog')!;
const input = document.querySelector<HTMLInputElement>('#docs-search')!;
const results = document.querySelector<HTMLUListElement>('.search-results')!;
const status = document.querySelector<HTMLElement>('.search-status')!;
let index: SearchEntry[] = [];
let loading: Promise<void> | undefined;
let selected = -1;
let previousFocus: HTMLElement | null = null;

function search() {
  const words = input.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
  results.replaceChildren(); selected = -1;
  if (!words.length) { status.textContent = 'Type to search the documentation.'; return; }
  const matches = index.map(entry => {
    const title = entry.title.toLowerCase();
    const summary = `${entry.description} ${entry.section}`.toLowerCase();
    const text = (entry.text ?? '').toLowerCase();
    return { entry, score: words.every(word => `${title} ${summary} ${text}`.includes(word)) ? words.reduce((sum, word) => sum + (title.includes(word) ? 10 : 0) + (summary.includes(word) ? 4 : 0) + 1, 0) : 0 };
  }).filter(match => match.score > 0).sort((a, b) => b.score - a.score).slice(0, 8);
  status.textContent = matches.length ? `${matches.length} matching ${matches.length === 1 ? 'page' : 'pages'}` : 'No matches. Try “repository”, “events”, or “install”.';
  matches.forEach(({ entry }) => {
    const li = document.createElement('li'); const a = document.createElement('a');
    const title = document.createElement('strong'); const description = document.createElement('span');
    a.href = entry.url; title.textContent = entry.title; description.textContent = entry.description;
    a.append(title, description); li.append(a); results.append(li);
  });
}

async function openSearch() {
  previousFocus = document.activeElement as HTMLElement;
  if (!dialog.open) dialog.showModal();
  input.focus();
  if (!loading) {
    status.textContent = 'Loading documentation…';
    loading = fetch(dialog.dataset.searchIndex!).then(async response => {
      if (!response.ok) throw new Error('Search unavailable');
      index = await response.json();
    }).catch(() => {
      loading = undefined;
      status.textContent = 'Search could not load. Use the documentation navigation, or try again.';
    });
  }
  await loading;
  if (index.length) search();
}
document.querySelectorAll('[data-search-open]').forEach(button => button.addEventListener('click', openSearch));
dialog.addEventListener('close', () => previousFocus?.focus());
dialog.addEventListener('click', event => {
  const bounds = dialog.getBoundingClientRect();
  if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close();
});
input.addEventListener('input', search);
dialog.querySelector('form')?.addEventListener('submit', event => {
  // Enter in the search field opens the selected result; the close button submits normally.
  if ((event as SubmitEvent).submitter) return;
  event.preventDefault();
  const links = results.querySelectorAll<HTMLAnchorElement>('a');
  if (links.length) links[Math.max(0, selected)].click();
});
input.addEventListener('keydown', event => {
  const links = Array.from(results.querySelectorAll<HTMLAnchorElement>('a'));
  if (event.key === 'Enter') {
    event.preventDefault();
    if (links.length) links[Math.max(0, selected)].click();
  }
  if (!['ArrowDown', 'ArrowUp'].includes(event.key) || !links.length) return;
  event.preventDefault();
  selected = (selected + (event.key === 'ArrowDown' ? 1 : -1) + links.length) % links.length;
  links.forEach((link, i) => { link.dataset.selected = String(i === selected); });
  links[selected].scrollIntoView({ block: 'nearest' });
});
document.addEventListener('keydown', event => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
    event.preventDefault(); dialog.open ? dialog.close() : openSearch();
  }
  if (event.key === 'Escape' && menu?.getAttribute('aria-expanded') === 'true') {
    menu.setAttribute('aria-expanded', 'false'); navigation?.classList.remove('is-open'); menu.focus();
  }
});
