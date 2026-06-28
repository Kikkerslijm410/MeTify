const jobsEl = document.querySelector('#jobs');
const filesEl = document.querySelector('#files');
const msg = document.querySelector('#message');

function selectedValues(form, name){
    return [...form.querySelector(`[name="${name}"]`).selectedOptions].map(o => o.value);
}

function initMultiSelects() {
    const closeAll = () => {
        document.querySelectorAll('.multi-select.open').forEach(dropdown => {
            dropdown.classList.remove('open');
        });
    };

    document.querySelectorAll('select[multiple].js-multi-select').forEach(select => {
        if (select.dataset.enhanced === 'true') return;

        select.dataset.enhanced = 'true';
        select.classList.add('multi-select-source');

        const wrapper = document.createElement('div');
        wrapper.className = 'multi-select';

        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'multi-select__button';

        const menu = document.createElement('div');
        menu.className = 'multi-select__menu';

        const updateText = () => {
            const count = select.selectedOptions.length;

            if (count === 0) {
                button.textContent = '0 Selected';
            } else {
                button.textContent = `${count} Selected`;
            }
        };

        [...select.options].forEach(option => {
            const row = document.createElement('div');
            row.className = 'multi-select__option';

            const checkbox = document.createElement('span');
            checkbox.className = 'multi-select__checkbox';

            const text = document.createElement('span');
            text.className = 'multi-select__text';
            text.textContent = option.textContent;

            row.appendChild(checkbox);
            row.appendChild(text);
            menu.appendChild(row);

            const syncRow = () => {
                row.classList.toggle('selected', option.selected);
            };

            row.addEventListener('click', event => {
                event.preventDefault();
                event.stopPropagation();
                option.selected = !option.selected;
                syncRow();
                updateText();

                select.dispatchEvent(new Event('change', { bubbles: true }));
            });

            syncRow();
        });

        button.addEventListener('click', event => {
            event.preventDefault();
            event.stopPropagation();

            const wasOpen = wrapper.classList.contains('open');

            closeAll();

            if (!wasOpen) {
                wrapper.classList.add('open');
            }
        });

        document.addEventListener('click', (event) => {
            document.querySelectorAll('.multi-select.open').forEach(dropdown => {
                if (!dropdown.contains(event.target)) {
                    dropdown.classList.remove('open');
                }
            });
        });

        wrapper.appendChild(button);
        wrapper.appendChild(menu);
        select.after(wrapper);
        updateText();
    });
}

function bytes(n) {
    return `${(n / 1024 ** 2).toFixed(1)} MB`;
}

async function api(url, options={}){
    const r = await fetch(url, options);
    if(!r.ok) throw new Error(await r.text());
    return r.json();
}

async function createJob(e){
    e.preventDefault();
    const form = e.target;
    const payload = {
        url: form.url.value,
        audio: selectedValues(form, 'audio'),
        lyrics: selectedValues(form, 'lyrics'),
        max_retries: form.max_retries.value,
        threads: form.max_threads.value,
        bitrate: form.bitrate.value,
        format: form.format.value,
    };

    try {
        await api('/api/jobs', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        msg.textContent = 'Download started';
        form.url.value = '';
        await refresh();
    } catch (err) {
        msg.textContent = `Fout: ${err.message}`;
    }
}

function renderJobs(jobs) {
    if (!jobs.length) {
        jobsEl.innerHTML = '<div class="item muted">No jobs.</div>';
        return;
    }

    jobsEl.innerHTML = jobs.map(j => `
        <div class="item">
            <div class="item-head">
                <strong>${j.id.slice(0, 8)}</strong>
                <span class="badge">${j.status}</span>
            </div>
            <div class="muted">${j.created_at || ''}</div>
            <div class="progress"><div class="bar" style="width:${j.progress || 0}%"></div></div>
            <div class="muted">${j.progress || 0}%</div>
            <pre class="log">${(j.log || []).join('\n')}</pre>
        </div>
    `).join('');
}

function renderFiles(files) {
        if (!files.length) {
            filesEl.innerHTML = '<div class="item muted">No files.</div>';
            return;
        }

    filesEl.innerHTML = files.map(f => `
        <div class="item">
            <div class="item-head">
                <div style="display:flex; justify-content:space-between; width:100%; align-items:center;">
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
    `).join('');
}

function downloadFile(filename) {
    fetch('/api/download', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename })
    })
    .then(res => {
        if (!res.ok) throw new Error('Download failed');
        return res.blob();
    })
    .then(blob => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        window.URL.revokeObjectURL(url);
    })
    .catch(err => alert(err));
}

function initSingleSelects() {
    document.querySelectorAll('select:not([multiple]).js-single-select').forEach(select => {
        if (select.dataset.enhanced === 'true') return;
        select.dataset.enhanced = 'true';

        select.style.display = 'none';

        const wrapper = document.createElement('div');
        wrapper.className = 'multi-select';

        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'multi-select__button';

        const menu = document.createElement('div');
        menu.className = 'multi-select__menu';

        const updateText = () => {
            button.textContent = select.selectedOptions[0]?.textContent;
        };

        [...select.options].forEach(option => {
            const row = document.createElement('div');
            row.className = 'multi-select__option';

            row.textContent = option.textContent;

            if (option.selected) {
                row.classList.add('selected');
            }

            row.addEventListener('click', () => {
                [...select.options].forEach(o => o.selected = false);
                option.selected = true;

                menu.querySelectorAll('.selected').forEach(el => el.classList.remove('selected'));
                row.classList.add('selected');

                updateText();
                wrapper.classList.remove('open');
                select.dispatchEvent(new Event('change', { bubbles: true }));
            });

            menu.appendChild(row);
        });

        button.addEventListener('click', () => {
            wrapper.classList.toggle('open');
        });

        wrapper.appendChild(button);
        wrapper.appendChild(menu);
        select.after(wrapper);

        updateText();
    });
}

async function deleteFile(name){
    await fetch(`/api/downloads/${name}`, {method:'DELETE'});
    await refresh();
}

async function refresh(){
    const [jobs, files] = await Promise.all([api('/api/jobs'), api('/api/downloads')]);
    renderJobs(jobs); renderFiles(files);
}

initMultiSelects();
initSingleSelects();
document.querySelector('#downloadForm').addEventListener('submit', createJob);
refresh();
setInterval(refresh, 2500);

setTimeout(() => {
    document.querySelectorAll('.log').forEach(el => {
        el.scrollTop = el.scrollHeight;
    });
}, 100);
