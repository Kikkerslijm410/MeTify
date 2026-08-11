const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];

const jobsEl = $('#jobs');
const filesEl = $('#files');
const msg = $('#message');
const selectAllEl = $('#select-all-files');
const selectionCountEl = $('#selection-count');

const render = (el, data, empty, fn) => el.innerHTML = data.length ? data.map(fn).join('') : empty;

const api = async (url, opts={}) => {
    const r = await fetch(url, opts);
    if (!r.ok) throw new Error(await r.text());
    return r.json();
};

const bytes = n => `${(n / 1024 ** 2).toFixed(1)} MB`;
const selectedValues = (form, name) => [...form[name].selectedOptions].map(o => o.value);

// Multi-select enhancement
function initSelects() {
    const closeAll = () => document.querySelectorAll('.multi-select.open').forEach(d => d.classList.remove('open'));

    document.querySelectorAll('.js-multi-select, .js-single-select').forEach(select => {
        if (select.dataset.enhanced) return;
        select.dataset.enhanced = true;

        const multi = select.multiple;
        select.style.display = 'none';

        const wrap = document.createElement('div');
        wrap.className = 'multi-select';

        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'multi-select__button';

        const menu = document.createElement('div');
        menu.className = 'multi-select__menu';

        const update = () => {
            btn.textContent = multi
                ? `${select.selectedOptions.length} Selected`
                : select.selectedOptions[0]?.textContent || '';
        };

        [...select.options].forEach(opt => {
            const row = document.createElement('div');
            row.className = 'multi-select__option';

            const label = document.createElement('span');
            label.textContent = opt.textContent;

            if (multi) {
                const checkbox = document.createElement('span');
                checkbox.className = 'multi-select__checkbox';

                const sync = () => {
                    row.classList.toggle('selected', opt.selected);
                    checkbox.textContent = opt.selected ? '✔' : '';
                };

                row.append(checkbox, label);

                row.onclick = () => {
                    opt.selected = !opt.selected;
                    sync();
                    update();
                    select.dispatchEvent(new Event('change', { bubbles: true }));
                };

                sync();
            } else {
                row.append(label);

                if (opt.selected) row.classList.add('selected');

                row.onclick = () => {
                    [...select.options].forEach(o => o.selected = false);
                    opt.selected = true;

                    menu.querySelectorAll('.selected').forEach(x => x.classList.remove('selected'));

                    row.classList.add('selected');
                    update();
                    wrap.classList.remove('open');

                    select.dispatchEvent(new Event('change', { bubbles: true }));
                };
            }

            menu.appendChild(row);
        });

        btn.onclick = () => {
            const isOpen = wrap.classList.contains('open');
            closeAll();
            if (!isOpen) wrap.classList.add('open');
        };

        wrap.append(btn, menu);
        select.after(wrap);
        update();
    });
}

async function createJob(e){
    e.preventDefault();
    const f = e.target;

    try {
        await api('/api/jobs', {
            method: 'POST',
            headers: {'Content-Type':'application/json'},
            body: JSON.stringify({
                url: f.url.value,
                audio: selectedValues(f, 'audio'),
                options: selectedValues(f, 'options'),
                max_retries: f.max_retries.value,
                threads: f.max_threads.value,
                bitrate: f.bitrate.value,
                format: f.format.value
            })
        });

        msg.textContent = 'Download started';
        f.url.value = '';
        refresh();
    } catch(e){
        msg.textContent = `Fout: ${e.message}`;
    }
}

function renderJobs(jobs){
    render(jobsEl, jobs, '<div class="item muted">No jobs.</div>', j => `
        <div class="item">
            <div class="item-head">
                <strong>${j.id.slice(0,8)}</strong>
                <span class="badge">${j.status}</span>
                <button class="icon-btn" onclick="deleteJob('${j.id}')">
                    <i class="fa-solid fa-trash-can"></i>
                </button>
            </div>
            <div class="muted">${j.created_at || ''}</div>
            <div class="progress"><div class="bar" style="width:${j.progress||0}%"></div></div>
            <div class="muted">${j.progress||0}%</div>
            <pre class="log">${(j.log||[]).join('\n')}</pre>
        </div>
    `);
}

async function deleteJob(id) {
    await fetch(`/api/jobs/${encodeURIComponent(id)}`, { method: 'DELETE' });
    refresh();
}

async function clearJobs() {
    await fetch('/api/jobs', { method: 'DELETE' });
    refresh();
}

async function downloadJobs() {
    const jobs = await api('/api/jobs');
    const blob = new Blob([JSON.stringify(jobs, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = Object.assign(document.createElement('a'), { href: url, download: 'jobs.json' });
    a.click();
    URL.revokeObjectURL(url);
    refresh();
}

function renderFiles(files) {
    const groups = {};

    files.forEach(file => {
        const baseName = file.name.replace(/\.(mp3|flac|m4a|wav|lrc)$/i, '');
        if (!groups[baseName]) groups[baseName] = [];
        groups[baseName].push(file);
    });

    const html = Object.entries(groups).map(([title, groupFiles]) => {

        const sorted = groupFiles.sort((a, b) => {
            const aIsLrc = a.name.toLowerCase().endsWith('.lrc');
            const bIsLrc = b.name.toLowerCase().endsWith('.lrc');
            if (aIsLrc && !bIsLrc) return 1;
            if (!aIsLrc && bIsLrc) return -1;
            return 0;
        });

        // Single files (like just an mp3 or just an lrc) are displayed without a group header
        const isGrouped = sorted.length > 1;
            return `
                <div class="song-group${isGrouped ? ' grouped' : ''}" data-group="${title}">
                    ${isGrouped ? `
                        <div class="song-group-header">
                            <input type="checkbox" class="group-checkbox">
                            <i class="fa-solid fa-folder"></i>
                            <div class="song-title">${title}</div>
                        </div>
                    ` : ''}


                <div class="song-files">
                    ${sorted.map(f => `
                        <div class="song-file">
                            <input type="checkbox" class="file-checkbox" value="${f.name}">

                            <div class="song-file-icon">
                                ${f.name.toLowerCase().endsWith('.lrc')
                                    ? '<i class="fa-solid fa-file-lines"></i>'
                                    : '<i class="fa-solid fa-music"></i>'}
                            </div>

                            <div class="song-file-info">
                                <div class="song-file-name">${isGrouped ? f.name : title}</div>
                                <div class="muted">${bytes(f.size)} • ${f.bitrate} • ${f.modified}</div>
                            </div>
                        </div>
                    `).join('')}
                </div>
            </div>
        `;
    }).join('');

    filesEl.innerHTML = html || '<div class="item muted">No files.</div>';
    syncSelectionState();
}

function syncSelectionState() {
    $$('.song-group').forEach(group => {
        const groupCb = group.querySelector('.group-checkbox');
        if (!groupCb) return;

        const fileCbs = [...group.querySelectorAll('.file-checkbox')];
        const checkedCount = fileCbs.filter(cb => cb.checked).length;

        groupCb.checked = checkedCount === fileCbs.length;
        groupCb.indeterminate = checkedCount > 0 && checkedCount < fileCbs.length;
    });

    const allFileCbs = $$('.file-checkbox');
    const allChecked = allFileCbs.filter(cb => cb.checked).length;

    selectAllEl.checked = allFileCbs.length > 0 && allChecked === allFileCbs.length;
    selectAllEl.indeterminate = allChecked > 0 && allChecked < allFileCbs.length;

    selectionCountEl.textContent = `${allChecked} geselecteerd`;

    const hasSelection = allChecked > 0;
    $$('.selection-bar .actions button').forEach(b => b.disabled = !hasSelection);
}

filesEl.addEventListener('change', e => {
    if (e.target.classList.contains('group-checkbox')) {
        const group = e.target.closest('.song-group');
        group.querySelectorAll('.file-checkbox').forEach(cb => cb.checked = e.target.checked);
    }
    syncSelectionState();
});

selectAllEl.addEventListener('change', () => {
    $$('.file-checkbox').forEach(cb => cb.checked = selectAllEl.checked);
    syncSelectionState();
});

async function refresh() {
    const jobs = await api('/api/jobs');
    renderJobs(jobs);

    const files = await api('/api/downloads');
    renderFiles(files);

    if ([...document.querySelectorAll('.badge')].some(b => b.textContent.trim() === 'running')) {
        setTimeout(refresh, 5000);
    }
}

const btn = $('#theme-toggle');
const icon = btn.querySelector('i');
let light = localStorage.getItem('theme') === 'light';

const applyTheme = () => {
    document.body.classList.toggle('light-mode', light);
    icon.className = `fa-solid fa-${light ? 'sun' : 'moon'}`;
};

btn.onclick = () => {
    light = !light;
    localStorage.setItem('theme', light ? 'light' : 'dark');
    applyTheme();
};

async function downloadFile(filename) {
    return downloadFiles([filename]);
}

async function downloadFiles(filenames) {
    const res = await fetch('/api/download', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filenames })
    });

    if (!res.ok) {
        msg.textContent = `Fout bij downloaden: ${await res.text()}`;
        return;
    }

    const blob = await res.blob();
    const isZip = filenames.length > 1;
    const downloadName = isZip ? 'MeTify.zip' : filenames[0];

    const url = URL.createObjectURL(blob);
    const a = Object.assign(document.createElement('a'), { href: url, download: downloadName });
    a.click();
    URL.revokeObjectURL(url);
}

async function downloadSelectedFiles() {
    const files = $$('.file-checkbox:checked').map(cb => cb.value);
    if (!files.length) return;
    downloadFiles(files);
}

async function deleteFile(name) {
    await fetch(`/api/downloads/${encodeURIComponent(name)}`, { method: 'DELETE' });
    refresh();
}

async function deleteSelectedFiles() {
    const files = $$('.file-checkbox:checked').map(cb => cb.value);

    await Promise.all(
        files.map(name =>
            fetch(`/api/downloads/${encodeURIComponent(name)}`, { method: 'DELETE' })
        )
    );

    refresh();
}

initSelects();
$('#downloadForm').onsubmit = createJob;

refresh();
applyTheme();
