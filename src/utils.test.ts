import { clamp, sleep } from './utils';

// Test utilities
let testCount = 0;
let passCount = 0;

function assert(condition: boolean, message: string) {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

function test(name: string, fn: () => void | Promise<void>) {
  testCount++;
  try {
    const result = fn();
    if (result instanceof Promise) {
      return result.then(() => {
        passCount++;
        console.log(`✓ ${name}`);
      }).catch((err) => {
        console.error(`✗ ${name}: ${err.message}`);
      });
    } else {
      passCount++;
      console.log(`✓ ${name}`);
    }
  } catch (err) {
    console.error(`✗ ${name}: ${(err as Error).message}`);
  }
}

// Sleep tests
test('sleep: should resolve after specified milliseconds', async () => {
  const start = Date.now();
  await sleep(10);
  const elapsed = Date.now() - start;
  assert(elapsed >= 10, `Expected elapsed >= 10, got ${elapsed}`);
});

test('sleep: should return a promise', () => {
  const result = sleep(1);
  assert(result instanceof Promise, 'sleep should return a Promise');
});

// Clamp tests
test('clamp: should return value when between min and max', () => {
  assert(clamp(5, 0, 10) === 5, 'clamp(5, 0, 10) should be 5');
  assert(clamp(0, 0, 10) === 0, 'clamp(0, 0, 10) should be 0');
  assert(clamp(10, 0, 10) === 10, 'clamp(10, 0, 10) should be 10');
});

test('clamp: should return min when value is below min', () => {
  assert(clamp(-5, 0, 10) === 0, 'clamp(-5, 0, 10) should be 0');
  assert(clamp(-100, -50, 50) === -50, 'clamp(-100, -50, 50) should be -50');
});

test('clamp: should return max when value is above max', () => {
  assert(clamp(15, 0, 10) === 10, 'clamp(15, 0, 10) should be 10');
  assert(clamp(100, -50, 50) === 50, 'clamp(100, -50, 50) should be 50');
});

test('clamp: should handle negative ranges', () => {
  assert(clamp(-5, -10, -1) === -5, 'clamp(-5, -10, -1) should be -5');
  assert(clamp(-15, -10, -1) === -10, 'clamp(-15, -10, -1) should be -10');
  assert(clamp(0, -10, -1) === -1, 'clamp(0, -10, -1) should be -1');
});

test('clamp: should handle floating point numbers', () => {
  assert(clamp(5.5, 0, 10) === 5.5, 'clamp(5.5, 0, 10) should be 5.5');
  assert(clamp(-0.5, 0, 10) === 0, 'clamp(-0.5, 0, 10) should be 0');
  assert(clamp(10.1, 0, 10) === 10, 'clamp(10.1, 0, 10) should be 10');
});

test('clamp: should throw when min > max', () => {
  try {
    clamp(5, 10, 0);
    throw new Error('Should have thrown');
  } catch (err) {
    const message = (err as Error).message;
    assert(
      message.includes('min (10) cannot be greater than max (0)'),
      `Expected error about min > max, got: ${message}`
    );
  }
});

test('clamp: should work with equal min and max', () => {
  assert(clamp(5, 10, 10) === 10, 'clamp(5, 10, 10) should be 10');
  assert(clamp(10, 10, 10) === 10, 'clamp(10, 10, 10) should be 10');
  assert(clamp(15, 10, 10) === 10, 'clamp(15, 10, 10) should be 10');
});

// Print summary
Promise.resolve().then(() => {
  console.log(`\n${passCount}/${testCount} tests passed`);
  process.exit(passCount === testCount ? 0 : 1);
});
