import { describe, expect, it } from 'vitest';
import { PACKAGE_NAME } from './index.js';

describe('@oep-exchange/signing package scaffold', () => {
  it('is wired into the workspace and exports its package identity', () => {
    expect(PACKAGE_NAME).toBe('@oep-exchange/signing');
  });
});
