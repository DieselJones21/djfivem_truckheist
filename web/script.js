const hud = document.getElementById('hud');
const fill = document.getElementById('hud-fill');
const percentEl = document.getElementById('hud-percent');
const titleEl = document.getElementById('hud-title');
const objectiveEl = document.getElementById('hud-objective');
const stages = document.querySelectorAll('.hud-stages span');

const stageOrder = ['locate', 'deliver', 'search', 'fence'];

function setStage(stage) {
    let reached = true;
    stages.forEach((el) => {
        const name = el.getAttribute('data-stage');
        el.classList.remove('active', 'done');
        if (name === stage) {
            el.classList.add('active');
            reached = false;
        } else if (reached) {
            el.classList.add('done');
        }
    });

    if (stage === 'complete') {
        stages.forEach((el) => {
            el.classList.remove('active');
            el.classList.add('done');
        });
    }
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'show') {
        hud.classList.remove('hidden');
        titleEl.textContent = data.title || 'TRUCK HEIST';
        objectiveEl.textContent = data.objective || '';
        const progress = Math.max(0, Math.min(100, Number(data.progress) || 0));
        fill.style.width = `${progress}%`;
        percentEl.textContent = `${progress}%`;
        setStage(data.stage || 'locate');
        return;
    }

    if (data.action === 'update') {
        if (data.title) titleEl.textContent = data.title;
        if (data.objective) objectiveEl.textContent = data.objective;
        if (typeof data.progress === 'number') {
            const progress = Math.max(0, Math.min(100, data.progress));
            fill.style.width = `${progress}%`;
            percentEl.textContent = `${progress}%`;
        }
        if (data.stage) setStage(data.stage);
        return;
    }

    if (data.action === 'hide') {
        hud.classList.add('hidden');
    }
});
