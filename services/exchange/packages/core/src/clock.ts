/**
 * An injectable time source — every place that needs "now" (publication
 * timestamps, audit records, license expiry checks) should take a
 * `Clock` rather than calling `new Date()` directly, so tests can supply
 * a fixed/fake clock instead of depending on real wall-clock time.
 */
export interface Clock {
  now(): Date;
}

export class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }
}
