import { audit, compare_policies } from './engine.js';

const $ = id => document.getElementById(id);
const escape = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const state = { policy: null, baseline: null, sourceEvents: [], events: [], report: null, selected: null, scenario: 'all' };
const explanations = {
  SENSITIVE_FLOW: '这次调用携带敏感标签。即使经过摘要或转换，标签也会沿 artifact 依赖继续传播。',
  APPROVAL_REUSED: '这份审批已被前一次操作使用。再次操作需要新的审批记录。',
  APPROVAL_MISSING: '调用没有引用审批。请由可信采集器记录审批，再关联该调用。',
  APPROVAL_UNKNOWN: '当前会话中找不到这份审批，不能借用另一个会话的授权。',
  APPROVAL_SCOPE: '审批绑定的工具或资源与当前调用不同，授权不适用。',
  APPROVAL_REVOKED: '引用的审批已被撤销。',
  APPROVAL_EXPIRED: '调用时间已到达或超过审批失效时间。',
  BUDGET_EXCEEDED: '累计的观察成本超过预算。被测试策略拒绝的历史调用仍计入已发生的成本。',
  RATE_EXCEEDED: '当前滑动窗口内的观察调用次数超过上限。',
  DEFAULT_DENY: '默认拒绝策略没有找到显式放行规则。',
  TOOL_DENIED: '工具与资源同时命中一条拒绝规则。',
  PREREQUISITE_MISSING: '在本会话的有效窗口内，缺少已成功完成的前置工具调用。',
};

function status(message, error = false) { $('status').textContent = message; $('status').classList.toggle('error', error); }
function parseEvents(text) {
  const s = text.trim();
  return s.startsWith('[') ? JSON.parse(s) : s.split(/\r?\n/).filter(s => s.trim()).map(s => JSON.parse(s));
}
function syncEditors() {
  $('policy-editor').value = JSON.stringify(state.policy, null, 2);
  $('trace-editor').value = state.events.map(e => JSON.stringify(e)).join('\n');
}
function replay(fromEditors = false) {
  const start = performance.now();
  try {
    const policyText = fromEditors ? $('policy-editor').value : JSON.stringify(state.policy);
    const traceText = fromEditors ? $('trace-editor').value : state.events.map(e => JSON.stringify(e)).join('\n');
    const report = JSON.parse(audit(policyText, traceText));
    if (report.error) throw new Error(report.error.message);
    state.policy = JSON.parse(policyText);
    state.events = parseEvents(traceText);
    if (fromEditors) { state.sourceEvents = state.events; state.scenario = 'custom'; }
    state.report = report;
    if (!state.events.some(e => e.id === state.selected)) state.selected = report.decisions.find(d => d.decision === 'deny')?.event_id || report.decisions[0]?.event_id || state.events[0]?.id;
    $('comparison').hidden = true;
    $('export-report').disabled = false;
    $('compare').disabled = false;
    render();
    status(`${report.events} 条事件已在本地重放 · ${(performance.now() - start).toFixed(1)} ms · 结果可重复，未执行任何工具`);
  } catch (error) {
    state.report = null;
    $('timeline').innerHTML = '<p class="empty">输入需要修正。下方编辑器保留了原始内容。</p>';
    $('inspector').textContent = '修正输入并重放后，将显示判定证据。';
    for (const id of ['calls', 'denied', 'allowed', 'cost']) $(id).textContent = '—';
    $('events-label').textContent = '输入无效';
    $('export-report').disabled = true;
    $('compare').disabled = true;
    $('comparison').hidden = true;
    status(error.message, true);
  }
}

function render() {
  const report = state.report;
  $('calls').textContent = report.calls;
  $('denied').textContent = report.denied;
  $('allowed').textContent = report.allowed;
  $('cost').textContent = report.observed_cost.toLocaleString('en-US');
  $('events-label').textContent = `${report.events} 条观察事件`;
  const byId = new Map(report.decisions.map(d => [d.event_id, d]));
  const onlyDenied = $('only-denied').checked;
  const visible = state.events.filter(e => !onlyDenied || byId.get(e.id)?.decision === 'deny');
  // Rendering is bounded separately from engine limits. Large imports remain
  // fully analyzed and exportable without creating 10,000 DOM buttons.
  const shown = visible.slice(0, 200);
  $('timeline').innerHTML = shown.map(event => {
    const d = byId.get(event.id);
    const verdict = d?.decision || 'control';
    const label = d ? (verdict === 'deny' ? 'DENY' : 'ALLOW') : event.kind === 'revoke' ? 'REVOKE' : 'APPROVAL';
    return `<button class="event ${verdict} ${event.id === state.selected ? 'selected' : ''}" data-event="${escape(event.id)}" aria-pressed="${event.id === state.selected}"><span class="event-icon" aria-hidden="true">${verdict === 'deny' ? '!' : verdict === 'control' ? '◇' : '↗'}</span><span class="event-main"><strong>${escape(event.id)}</strong><small><span>${String(event.at_ms).padStart(4, '0')} ms</span>${escape(event.tool || event.kind)} · ${escape(event.session)}</small></span><span class="verdict ${verdict}">${label}</span></button>`;
  }).join('') || '<p class="empty">当前筛选下没有调用。</p>';
  if (visible.length > 200) $('timeline').insertAdjacentHTML('beforeend', '<p class="empty">展示前 200 条；导出报告包含全部判定。</p>');
  for (const button of $('timeline').querySelectorAll('button')) button.addEventListener('click', () => { state.selected = button.dataset.event; render(); });
  document.querySelectorAll('[data-scenario]').forEach(button => button.classList.toggle('active', button.dataset.scenario === state.scenario));
  inspect();
}

function ancestors(event) {
  const producers = new Map(state.events.filter(e => e.output).map(e => [`${e.session}\0${e.output}`, e]));
  const seen = new Set();
  const pending = [event];
  while (pending.length) {
    const current = pending.pop();
    if (!current || seen.has(current.id)) continue;
    seen.add(current.id);
    for (const input of current.inputs || []) pending.push(producers.get(`${current.session}\0${input}`));
  }
  return state.events.filter(e => seen.has(e.id));
}
function inspect() {
  const event = state.events.find(e => e.id === state.selected);
  if (!event) { $('inspector').innerHTML = '<p class="inspect-sub">选择一条调用，查看判定和上游证据。</p>'; return; }
  const d = state.report.decisions.find(d => d.event_id === event.id);
  let html = `<div class="inspect-id">${escape(event.id)}</div><div class="inspect-sub">${escape(event.tool || event.kind)}<br>${escape(event.resource || '控制事件')}<br>会话 ${escape(event.session)} · 序号 ${event.seq}</div>`;
  if (!d) html += `<div class="finding"><p>审批控制事件。${event.kind === 'approve' ? `到 ${event.expires_ms} ms 失效；工具与资源均精确绑定。` : '撤销所引用的审批。'}</p></div>`;
  else if (!d.findings.length) html += '<div class="finding"><p>当前策略允许这次调用。继续保留其数据来源，供后续调用判断。</p></div>';
  else html += d.findings.map(f => `<div class="finding"><strong>${escape(f.code)}</strong><p>${escape(explanations[f.code] || f.message)}</p><small>规则 ${escape(f.rule_id)}${f.evidence.length ? '<br>证据 ' + escape(f.evidence.join(' → ')) : ''}</small></div>`).join('');
  if (d?.taints.length) html += d.taints.map(t => `<span class="tag">${escape(t.label)}</span>`).join('');
  const chain = ancestors(event);
  if (chain.length > 1) {
    const shown = chain.slice(-8);
    html += `<div class="lineage"><p class="lineage-title">ARTIFACT 依赖 · 按观察顺序排列${chain.length > 8 ? '（末 8 个节点）' : ''}</p><div class="lineage-chain">${shown.map((e, i) => `${i ? '<span class="lineage-arrow">↓</span>' : ''}<span class="lineage-node ${e.id === event.id ? 'focus' : ''}">${escape(e.id)}</span>`).join('')}</div></div>`;
  }
  $('inspector').innerHTML = html;
}

function useControls() {
  const value = Number($('budget').value);
  if (!Number.isInteger(value) || value < 0 || value > 2147483647 || $('budget').value.trim() === '') { status('预算需要填写 0 到 2147483647 之间的整数。', true); return; }
  const rules = state.policy.rules.filter(r => !['protect-secrets', 'consent-to-delete', 'model-budget'].includes(r.id));
  if ($('block-flow').checked) rules.push({ id: 'protect-secrets', kind: 'block_labels', tool: 'net.*', labels: ['secret', 'personal'] });
  if ($('need-approval').checked) rules.push({ id: 'consent-to-delete', kind: 'require_approval', tool: 'fs.delete' });
  rules.push({ id: 'model-budget', kind: 'budget', tool: 'llm.*', limit: value });
  state.policy = { ...state.policy, rules };
  syncEditors();
  replay();
}

for (const id of ['block-flow', 'need-approval', 'budget']) $(id).addEventListener('change', useControls);
$('only-denied').addEventListener('change', () => state.report && render());
$('replay').addEventListener('click', () => replay(true));
$('compare').addEventListener('click', () => {
  if (!state.report) return;
  const diff = JSON.parse(compare_policies(JSON.stringify(state.baseline), JSON.stringify(state.policy), state.events.map(e => JSON.stringify(e)).join('\n')));
  if (diff.error) { status(diff.error.message, true); return; }
  $('comparison').hidden = false;
  $('comparison').innerHTML = `相对基线：<strong>${diff.newly_denied}</strong> 次新增拒绝 · <strong>${diff.newly_allowed}</strong> 次解除拒绝<br>${diff.explanation_changes} 次判定解释变化${diff.changes.length ? '<br>' + diff.changes.map(c => escape(c.event_id)).join(' · ') : '<br>两套策略的判定相同。'}`;
});
document.querySelectorAll('[data-scenario]').forEach(button => button.addEventListener('click', () => {
  state.scenario = button.dataset.scenario;
  const ids = { flow: ['read-private', 'summarize', 'external-upload', 'read-public', 'publish-public'], approval: ['grant-delete', 'delete-approved', 'reuse-approval'], budget: ['model-first', 'model-second'] };
  state.events = state.scenario === 'all' ? state.sourceEvents : state.sourceEvents.filter(e => ids[state.scenario].includes(e.id));
  state.selected = null;
  syncEditors(); replay();
}));
$('import-button').addEventListener('click', () => $('trace-file').click());
$('trace-file').addEventListener('change', async () => {
  const file = $('trace-file').files[0];
  if (!file) return;
  if (file.size > 16 * 1024 * 1024) { status('文件超过 16 MiB 上限。', true); return; }
  $('trace-editor').value = await file.text();
  replay(true);
  $('trace-file').value = '';
});
$('export-report').addEventListener('click', () => {
  if (!state.report) return;
  const url = URL.createObjectURL(new Blob([JSON.stringify(state.report, null, 2)], { type: 'application/json' }));
  const link = document.createElement('a'); link.href = url; link.download = 'agentcanary-report.json'; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});

try {
  const responses = await Promise.all(['policy.json', 'baseline.json', 'incident.jsonl'].map(async file => {
    const response = await fetch(`data/${file}`); if (!response.ok) throw new Error('样例数据未找到，请重新构建项目。'); return response.text();
  }));
  state.policy = JSON.parse(responses[0]); state.baseline = JSON.parse(responses[1]);
  state.events = parseEvents(responses[2]); state.sourceEvents = state.events;
  syncEditors(); replay();
} catch (error) { status(error.message, true); }
