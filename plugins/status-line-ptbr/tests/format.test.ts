import { expect, test } from 'claude-code/testing'
import { effortLabel, formatPct, formatReset, modelLabel, pctColor, segments } from '../hooks/format.js'

const NOW = Date.parse('2026-10-03T12:00:00Z')

test('pctColor: green < 50, yellow < 80, red >= 80', async () => {
  expect(pctColor(0)).toBe('green')
  expect(pctColor(49.4)).toBe('green')
  expect(pctColor(50)).toBe('yellow')
  expect(pctColor(79.6)).toBe('red')
  expect(pctColor(80)).toBe('red')
})

test('formatReset: minutes, hours, days and past', async () => {
  expect(formatReset('2026-10-03T12:42:00Z', NOW)).toBe('42min')
  expect(formatReset('2026-10-03T15:19:30Z', NOW)).toBe('3h 19min')
  expect(formatReset('2026-10-09T01:00:00Z', NOW)).toBe('5d 13h')
  expect(formatReset('2026-10-03T11:00:00Z', NOW)).toBe('agora')
  expect(formatReset(undefined, NOW)).toBeUndefined()
})

test('effortLabel translates known levels and passes the rest through', async () => {
  expect(effortLabel('low')).toBe('baixo')
  expect(effortLabel('medium')).toBe('médio')
  expect(effortLabel('high')).toBe('alto')
  expect(effortLabel('xhigh')).toBe('extra-alto')
  expect(effortLabel('max')).toBe('máximo')
  expect(effortLabel(12000)).toBe('12000')
})

test('segments builds the full line in the bash script order', async () => {
  const line = segments({
    model: 'Opus 5.5 (1M context)',
    effort: 'high',
    context: { window: 1000000, percent: 6 },
    rateLimits: [
      { kind: 'seven_day', percentUsed: 82, resetsAt: '2026-10-09T01:00:00Z' },
      { kind: 'five_hour', percentUsed: 13, resetsAt: '2026-10-03T15:19:30Z' },
    ],
    now: NOW,
  })
  expect(line.map((p) => p.map((s) => s.text).join('')).join(' | ')).toBe(
    'Opus 5.5 (1M context) (esforço alto) | Contexto: 6% | Sessao: 13% (reseta em 3h 19min) | Semanal: 82% (reseta em 5d 13h)',
  )
  expect(line[1][1]).toEqual({ text: '6%', color: 'green' })
  expect(line[3][1]).toEqual({ text: '82%', color: 'red' })
})

test('segments omits what the engine has no figure for', async () => {
  const line = segments({ model: 'Sonnet', context: { window: 200000 }, rateLimits: [], now: NOW })
  expect(line.map((p) => p.map((s) => s.text).join('')).join(' | ')).toBe('Sonnet')
})

test('modelLabel turns a model id into its display name', async () => {
  expect(modelLabel('claude-opus-5-5[1m]')).toBe('Opus 5.5 (1M context)')
  expect(modelLabel('claude-sonnet-5-5')).toBe('Sonnet 5.5')
  expect(modelLabel('claude-haiku-4-5-20251001')).toBe('Haiku 4.5')
  expect(modelLabel('claude-fable-5-1')).toBe('Fable 5.1')
  expect(modelLabel('Opus 5.5 (1M context)')).toBe('Opus 5.5 (1M context)')
  expect(modelLabel('gpt-6.1-sol')).toBe('gpt-6.1-sol')
})

test('modelLabel handles dated snapshots, major-only and legacy ids', async () => {
  expect(modelLabel('claude-sonnet-4-20250514')).toBe('Sonnet 4')
  expect(modelLabel('claude-opus-5')).toBe('Opus 5')
  expect(modelLabel('claude-opus-4-1-20250805')).toBe('Opus 4.1')
  expect(modelLabel('claude-3-5-sonnet-20241022')).toBe('Sonnet 3.5')
  expect(modelLabel('claude-3-opus-20240229')).toBe('Opus 3')
  expect(modelLabel('claude-sonnet-5-5[1m]')).toBe('Sonnet 5.5 (1M context)')
})

test('percentages round half to even, like printf %.0f in the bash script', async () => {
  expect(formatPct(12.5)).toBe('12%')
  expect(formatPct(13.5)).toBe('14%')
  expect(formatPct(50.5)).toBe('50%')
  expect(formatPct(49.6)).toBe('50%')
  expect(pctColor(80.5)).toBe('red')
  expect(pctColor(79.5)).toBe('red')
  expect(pctColor(78.5)).toBe('yellow')
  expect(pctColor(49.5)).toBe('yellow')
  expect(pctColor(48.5)).toBe('green')
})
