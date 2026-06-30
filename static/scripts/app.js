const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];

const jobsEl = $('#jobs');
const filesEl = $('#files');
const msg = $('#message');

const api = async (url, opts={}) => {
    const r = await fetch(url, opts);
    if (!r.ok) throw new Error(await r.text());
    return r.json();
};

const bytes = n => `${(n / 1024 ** 2).toFixed(1)} MB`;
const selectedValues = (form, name) => [...form[name].selectedOptions].map(o => o.value);

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

                row.onclick = e => {
                    opt.selected = !opt.selected;
                    sync();
                    update();
                    select.dispatchEvent(new Event('change', { bubbles: true }));
                };

                sync();
            } else {
                row.append(label);

                if (opt.selected) row.classList.add('selected');

                row.onclick = e => {
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

        btn.onclick = e => {
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
                lyrics: selectedValues(f, 'lyrics'),
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

const render = (el, data, empty, fn) => el.innerHTML = data.length ? data.map(fn).join('') : empty;

function renderJobs(jobs){
    render(jobsEl, jobs, '<div class="item muted">No jobs.</div>', j => `
        <div class="item">
            <div class="item-head">
                <strong>${j.id.slice(0,8)}</strong>
                <span class="badge">${j.status}</span>
            </div>
            <div class="muted">${j.created_at || ''}</div>
            <div class="progress"><div class="bar" style="width:${j.progress||0}%"></div></div>
            <div class="muted">${j.progress||0}%</div>
            <pre class="log">${(j.log||[]).join('\n')}</pre>
        </div>
    `);
}

function renderFiles(files){
    render(filesEl, files, '<div class="item muted">No files.</div>', f => `
        <div class="item">
            <div class="item-head">
                <div style="display:flex;justify-content:space-between;width:100%">
                    <div>
                        <strong>${f.name}</strong>
                        <div class="muted">${bytes(f.size)} • ${f.modified}</div>
                    </div>
                    <div class="actions">
                        <button class="icon-btn" onclick="downloadFile('${f.name}')" title="Download">
                            <i class="fa-solid fa-download" style="color: #22c55e;"></i>
                        </button>
                        <button class="icon-btn" onclick="deleteFile('${f.name}')" title="Delete">
                            <i class="fa-solid fa-trash-can" style="color: #ef4444;"></i>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `);
}

const downloadFile = filename =>
    fetch('/api/download', {
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ filename })
    })
    .then(r => r.blob())
    .then(b => {
        const url = URL.createObjectURL(b);
        const a = Object.assign(document.createElement('a'), {href:url, download:filename});
        a.click();
        URL.revokeObjectURL(url);
    });

const deleteFile = async name => {
    await fetch(`/api/downloads/${name}`, {method:'DELETE'});
    refresh();
};

async function refresh() {
    const jobs = await api('/api/jobs');
    renderJobs(jobs);

    if ([...document.querySelectorAll('.badge')].some(b => b.textContent.trim() === 'running')) {
        const files = await api('/api/downloads');
        renderFiles(files);
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

initSelects();
$('#downloadForm').onsubmit = createJob;

refresh();
applyTheme();
