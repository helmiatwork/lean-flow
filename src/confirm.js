import { createInterface } from 'node:readline/promises'
import { stdin, stdout } from 'node:process'

async function ttyAsk(question) {
  const rl = createInterface({ input: stdin, output: stdout })
  const answer = await rl.question(question)
  rl.close()
  return answer.trim().toLowerCase()
}

export async function shouldProceed(missingNames, { yes = false, ask = ttyAsk } = {}) {
  if (missingNames.length === 0) return false
  if (yes) return true
  const answer = await ask(`Will install: ${missingNames.join(', ')}. Proceed? [Y/n] `)
  return answer === '' || answer === 'y' || answer === 'yes'
}
