import { expect, mock, test } from 'claude-code/testing'

const BAND = {
  plugin: 'status-line-ptbr',
  component: 'AbovePrompt',
  requestId: 'above-prompt',
  surface: 'terminal',
  viewport: { columns: 160, rows: 40 },
  props: { hasSurvey: false, isWorking: false, maxRows: 4, bodyColumns: 150, scroll: { offset: 0, bodyRows: 4 }, view: {} },
} as const

function stubSession(on, usage, settings = {}, model = () => 'claude-opus-5-5[1m]') {
  mock.clock(on, { now: Date.parse('2026-10-03T12:00:00Z') })
  on('session.start', () => ({ cwd: '/work' }))
  on('session.model', () => ({ value: model() }))
  on('session.usage', () => ({ value: usage }))
  on('settings.read', () => ({ value: settings }))
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['others'] }))
}

test('draws the status line in the band above the prompt', async ($, on) => {
  stubSession(
    on,
    {
      context: { window: 1000000, percent: 6 },
      rateLimits: [{ kind: 'five_hour', percentUsed: 55, resetsAt: '2026-10-03T13:05:00Z' }],
    },
    { effortLevel: 'high' },
  )
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: 'Opus 5.5 (1M context)' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: ' (esforço alto)' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '55%' })).toMatchObject({ props: { color: 'yellow' } })
  expect(await ui.find({ type: 'Text', text: ' (reseta em 1h 5min)' })).toBeDefined()
})

test('effort follows the main turn, not a subagent step', async ($, on) => {
  stubSession(on, { context: { window: 200000 }, rateLimits: [] }, { effortLevel: 'low' })
  on('turn.start', ($, e) => ({ turnId: e.turnId }))
  on('turn.step', async function* ($, e) {
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null }
  })
  const drain = async (stream) => {
    let s = await stream.next()
    while (s.done !== true) s = await stream.next()
  }
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  await $.turn.start({ text: 'oi', turnId: 'main' })
  await drain($.turn.step({ turnId: 'main', index: 0, model: 'claude-opus-5-5', effort: 'max', messageCount: 1 }))
  await drain($.turn.step({ turnId: 'main', index: 1, model: 'haiku', effort: 'low', messageCount: 1, agentId: 'a1' }))
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: ' (esforço máximo)' })).toBeDefined()
})

test('initial effort prefers the per-model setting', async ($, on) => {
  stubSession(
    on,
    { context: { window: 1000000 }, rateLimits: [] },
    { effortLevel: 'low', modelSettings: { 'claude-opus-5-5': { effortLevel: 'xhigh' } } },
  )
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: ' (esforço extra-alto)' })).toBeDefined()
})

const drainSteps = async (stream) => {
  let s = await stream.next()
  while (s.done !== true) s = await stream.next()
}

function stubStep(on) {
  on('turn.step', async function* ($, e) {
    return { turnId: e.turnId, index: e.index, answer: '', toolUses: [], stopReason: 'end_turn', usage: null }
  })
}

test('a main-loop step updates effort even without a turn.start seen (reload mid-turn)', async ($, on) => {
  stubSession(on, { context: { window: 200000 }, rateLimits: [] }, { effortLevel: 'high' })
  stubStep(on)
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  await drainSteps($.turn.step({ turnId: 'running', index: 3, model: 'claude-opus-5-5', effort: 'max', messageCount: 9 }))
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: ' (esforço máximo)' })).toBeDefined()
})

test('switching model drops the effort observed for the previous model', async ($, on) => {
  let model = 'claude-opus-5-5[1m]'
  stubSession(
    on,
    { context: { window: 200000 }, rateLimits: [] },
    { modelSettings: { 'claude-opus-5-5': { effortLevel: 'high' }, 'claude-sonnet-5-5': { effortLevel: 'low' } } },
    () => model,
  )
  stubStep(on)
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  await drainSteps($.turn.step({ turnId: 't', index: 0, model: 'claude-opus-5-5', effort: 'max', messageCount: 1 }))
  model = 'claude-sonnet-5-5'
  const ui = await $.ui.mount(BAND)
  expect(await ui.find({ type: 'Text', text: 'Sonnet 5.5' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: ' (esforço baixo)' })).toBeDefined()
})

test('switching away and back does not resurrect the old observed effort', async ($, on) => {
  let model = 'claude-opus-5-5'
  stubSession(
    on,
    { context: { window: 200000 }, rateLimits: [] },
    { modelSettings: { 'claude-opus-5-5': { effortLevel: 'high' }, 'claude-sonnet-5-5': { effortLevel: 'low' } } },
    () => model,
  )
  stubStep(on)
  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  await drainSteps($.turn.step({ turnId: 't', index: 0, model: 'claude-opus-5-5', effort: 'max', messageCount: 1 }))
  model = 'claude-sonnet-5-5'
  const sonnet = await $.ui.mount(BAND)
  expect(await sonnet.find({ type: 'Text', text: ' (esforço baixo)' })).toBeDefined()
  await sonnet.unmount()
  model = 'claude-opus-5-5'
  const opus = await $.ui.mount(BAND)
  expect(await opus.find({ type: 'Text', text: ' (esforço alto)' })).toBeDefined()
})
