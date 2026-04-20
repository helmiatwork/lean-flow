export const sleep = (ms: number): Promise<void> => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};

/**
 * Clamps a number between a minimum and maximum value.
 * @param value The value to clamp
 * @param min The minimum allowed value
 * @param max The maximum allowed value
 * @returns The clamped value
 */
export const clamp = (value: number, min: number, max: number): number => {
  if (min > max) {
    throw new Error(`min (${min}) cannot be greater than max (${max})`);
  }
  return Math.max(min, Math.min(max, value));
};
