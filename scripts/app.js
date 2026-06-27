const jobsEl = document.querySelector('#jobs');
const filesEl = document.querySelector('#files');
const msg = document.querySelector('#message');

function selectedValues(form, name){
    return [...form.querySelector(`[name="${name}"]`).selectedOptions].map(o => o.value);
}

function bytes(n){
    if(n < 1024) return `${n} B`;
    if(n < 1024**2) return `${(n/1024).toFixed(1)} KB`;
    if(n < 1024**3) return `${(n/1024**2).toFixed(1)} MB`;
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

    try{
        await api('/api/jobs', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload)});
        msg.textContent = 'Download started ✅';
        form.url.value = '';
        await refresh();
    }catch(err){
        msg.textContent = `Fout: ${err.message}`;
    }
}

function renderJobs(jobs){
    if(!jobs.length){ jobsEl.innerHTML = '<p class="muted">No jobs.</p>'; return; }
    jobsEl.innerHTML = jobs.map(j => `
        <div class="item">
        <div class="item-head">
            <div><strong>${j.id.slice(0,8)}</strong><div class="muted">${j.created_at || ''}</div></div>
            <span class="badge">${j.status}</span>
        </div>
        <div class="progress"><div class="bar" style="width:${j.progress || 0}%"></div></div>
        <div class="muted">${j.progress || 0}%</div>
        <div class="log">
            ${(j.log || []).join('\n')}
        </div>
        </div>`).join('');
}

function renderFiles(files){
    if(!files.length){
        filesEl.innerHTML = '<p class="muted">No files.</p>';
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


async function deleteFile(name){
    await fetch(`/api/downloads/${name}`, {method:'DELETE'});
    await refresh();
}

async function refresh(){
    const [jobs, files] = await Promise.all([api('/api/jobs'), api('/api/downloads')]);
    renderJobs(jobs); renderFiles(files);
}

document.querySelector('#downloadForm').addEventListener('submit', createJob);
refresh();
setInterval(refresh, 2500);

setTimeout(() => {
    document.querySelectorAll('.log').forEach(el => {
        el.scrollTop = el.scrollHeight;
    });
}, 100);
