export const sleep = (ms) => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};

/**
 * Clamps a number between a minimum and maximum value.
 * @param value The value to clamp
 * @param min The minimum allowed value
 * @param max The maximum allowed value
 * @returns The clamped value
 */
export const clamp = (value, min, max) => {
  if (min > max) {
    throw new Error(`min (${min}) cannot be greater than max (${max})`);
  }
  return Math.max(min, Math.min(max, value));
};
