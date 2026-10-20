import { reduceQty } from '../src/state/cart';
describe('reduceQty', () => {
  it('never goes below 0 or above the per-order cap / 99', () => {
    expect(reduceQty(1, -5)).toBe(0); expect(reduceQty(98, 5)).toBe(99); expect(reduceQty(2, 5, 4)).toBe(4); expect(reduceQty(3, 1, null)).toBe(4);
  });
});
